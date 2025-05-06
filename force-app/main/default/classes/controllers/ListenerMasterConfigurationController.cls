/**
 * @description Controller for listenerMasterConfiguration component
 */
public with sharing class ListenerMasterConfigurationController {
    // New method for lightweight error logging via Platform Events
    private static void logError(String errorType, String errorMessage, String details) {
        try {
            // Use standard System.debug for logging that doesn't require custom objects
            System.debug(LoggingLevel.ERROR, 'Flowdometer Error (' + errorType + '): ' + errorMessage);
            System.debug(LoggingLevel.ERROR, 'Details: ' + details);
            
            // Only send emails if the admin notification feature is enabled
            Boolean adminNotificationsEnabled = FeatureFlagUtil.isEnabled(FeatureFlagUtil.FEATURE_ADMIN_NOTIFICATIONS);
            
            // You could optionally send an email to admins for critical errors
            if (errorType == 'CRITICAL' && adminNotificationsEnabled) {
                // This only executes for truly critical errors that need immediate attention
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                
                // Get the org-wide email address to use as the sender
                OrgWideEmailAddress[] owea = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = 'Flowdometer Support' LIMIT 1];
                if (!owea.isEmpty()) {
                    mail.setOrgWideEmailAddressId(owea[0].Id);
                }
                
                // Set email properties - this can be improved to use Custom Settings/Metadata for admin emails
                String[] toAddresses = new String[]{'admin@example.com'};
                mail.setToAddresses(toAddresses);
                mail.setSubject('Flowdometer Critical Error: ' + errorType);
                mail.setPlainTextBody('Error: ' + errorMessage + '\n\nDetails: ' + details);
                
                // Attempt to send the email
                try {
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                } catch(Exception e) {
                    System.debug(LoggingLevel.WARN, 'Could not send notification email: ' + e.getMessage());
                }
            }
        } catch (Exception e) {
            // Fail silently - don't let logging errors affect functionality
            System.debug(LoggingLevel.ERROR, 'Error in error logging: ' + e.getMessage());
        }
    }

    @AuraEnabled(Cacheable=true)
    public static Map<String, String> getAllSObjectsInOrg() {
        try {
            return MetaDataUtilityCls.getAllSObjectsInOrg();
        } catch (CalloutException ce) {
            logError('CALLOUT', 'Timeout getting SObjects', ce.getMessage() + '\n' + ce.getStackTraceString());
            System.debug(LoggingLevel.ERROR, 'Callout error: ' + ce.getMessage() + '\n' + ce.getStackTraceString());
            throw new AuraHandledException('The request timed out. Please try again later.');
        } catch (Exception e) {
            logError('GENERAL', 'Error getting SObjects', e.getMessage() + '\n' + e.getStackTraceString());
            System.debug(LoggingLevel.ERROR, 'Error getting objects: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(Cacheable=true)
    public static Map<String, String> getSObjectFields(String objectName) {
        try {
            if (String.isBlank(objectName)) {
                throw new AuraHandledException('Object name cannot be empty');
            }
            return MetaDataUtilityCls.getSObjectFields(objectName);
        } catch (CalloutException ce) {
            System.debug(LoggingLevel.ERROR, 'Callout error: ' + ce.getMessage() + '\n' + ce.getStackTraceString());
            throw new AuraHandledException('The request timed out. Please try again later.');
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error getting fields: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(Cacheable=true)
    public static String checkFieldHistoryStatus(
        String sObjectApiName,
        String fieldName
    ) {
        try {
            // Check if this is a managed package object that's not our own
            if (sObjectApiName.contains('__') && 
                sObjectApiName.split('__').size() > 2 && 
                !sObjectApiName.startsWith('Flowdometer__')) {
                
                return 'WARNING: ' + sObjectApiName + ' appears to be from a managed package. ' +
                       'You can proceed, but some features like field history tracking or lookup creation may not work ' +
                       'depending on the package settings.';
            }
            
            return MetaDataUtilityCls.checkFieldHistoryStatus(
                sObjectApiName,
                fieldName
            );
        } catch (Exception e) {
            String errorMsg = 'Error checking field history status: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, errorMsg + '\n' + e.getStackTraceString());
            
            // Provide a more user-friendly message
            if (e.getMessage().contains('insufficient access')) {
                throw new AuraHandledException('You do not have sufficient permissions to enable history tracking on this object. Please contact your administrator.');
            } else if (e.getMessage().contains('managed package')) {
                throw new AuraHandledException('This object is from a managed package and may have restrictions on field modifications. The tracking will continue, but some features may be limited.');
            } else {
                throw new AuraHandledException(errorMsg);
            }
        }
    }

    @AuraEnabled
    public static String createListenerRecord(Listener__c newRecord) {
        try {
            // Check if permissions are sufficient before attempting insert
            if (!Schema.sObjectType.Flowdometer__Listener__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create Listener records.');
            }
            
            // Check if the object has reached its field limit
            String objectName = newRecord.Flowdometer__Object_Name__c;
            if (String.isNotBlank(objectName)) {
                try {
                    Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
                        .get(objectName)
                        ?.getDescribe()
                        .fields.getMap();
                    
                    if (fieldMap != null && fieldMap.size() >= 495) { // Buffer for the 500 field limit
                        throw new AuraHandledException('The object ' + objectName + ' is approaching the field limit of 500 custom fields. This might prevent lookup field creation.');
                    }
                } catch (Exception fex) {
                    // Log but don't block - this is just a warning check
                    System.debug(LoggingLevel.WARN, 'Could not check field limits: ' + fex.getMessage());
                }
            }
            
            // Perform the insert operation
            Database.SaveResult result = Database.insert(newRecord, false); // Using false to get errors instead of exceptions
            if (result.isSuccess()) {
                return newRecord.Id;
            } else {
                String errorMsg = 'Failed to create Listener record: ';
                for (Database.Error err : result.getErrors()) {
                    errorMsg += err.getMessage() + ' ';
                }
                throw new AuraHandledException(errorMsg);
            }
        } catch (DmlException dmlEx) {
            System.debug(LoggingLevel.ERROR, 'DML error creating Listener: ' + dmlEx.getMessage() + '\n' + dmlEx.getStackTraceString());
            
            String userMsg = 'Could not create the Listener record. ';
            if (dmlEx.getMessage().containsIgnoreCase('FIELD_CUSTOM_VALIDATION_EXCEPTION')) {
                userMsg += 'A validation rule is preventing the creation. ';
            } else if (dmlEx.getMessage().containsIgnoreCase('REQUIRED_FIELD_MISSING')) {
                userMsg += 'A required field is missing. ';
            } else if (dmlEx.getMessage().containsIgnoreCase('DUPLICATE_VALUE')) {
                userMsg += 'This combination of object and field already has a Listener. ';
            }
            
            throw new AuraHandledException(userMsg + dmlEx.getMessage());
        } catch (AuraHandledException aex) {
            // Just rethrow these as they're already formatted for users
            throw aex;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error creating Listener: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        }
    }
}
