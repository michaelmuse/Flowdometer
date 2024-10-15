/**
 * @description Controller for listenerMasterConfiguration component
 */
public with sharing class ListenerMasterConfigurationController {
    @AuraEnabled(Cacheable=true)
    public static Map<String, String> getAllSObjectsInOrg() {
        try {
            return MetaDataUtilityCls.getAllSObjectsInOrg();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(Cacheable=true)
    public static Map<String, String> getSObjectFields(String objectName) {
        try {
            return MetaDataUtilityCls.getSObjectFields(objectName);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(Cacheable=true)
    public static String checkFieldHistoryStatus(
        String sObjectApiName,
        String fieldName
    ) {
        try {
            return MetaDataUtilityCls.checkFieldHistoryStatus(
                sObjectApiName,
                fieldName
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String createListenerRecord(Listener__c newRecord) {
        try {
            Database.insert(newRecord);
            return newRecord.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
