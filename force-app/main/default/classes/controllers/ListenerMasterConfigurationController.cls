/**
 * @description Controller for listenerMasterConfiguration component
 */
public with sharing class ListenerMasterConfigurationController {
    // Constants for email sender name
    private static final String FLOWDOMETER_SUPPORT = 'Flowdometer Support';
    
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
                
                // Get the org-wide email address to use as the sender - use bind variable to prevent SOQL injection
                String senderName = FLOWDOMETER_SUPPORT; // Use constant instead of hardcoded string
                OrgWideEmailAddress[] owea = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = :senderName LIMIT 1];
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
            // Use `with sharing` in this method to enforce sharing rules
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
            // Validate input parameter
            if (String.isBlank(objectName)) {
                throw new AuraHandledException('Object name cannot be empty');
            }
            
            // Validate object name for potential injection
            if (!Pattern.matches('^[a-zA-Z0-9_]+$', objectName) && 
                !Pattern.matches('^[a-zA-Z0-9_]+__[a-zA-Z0-9_]+$', objectName) &&
                !Pattern.matches('^[a-zA-Z0-9_]+__[a-zA-Z0-9_]+__[a-zA-Z0-9_]+$', objectName)) {
                throw new AuraHandledException('Invalid object name format');
            }
            
            // Fetch fields from the object
            Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe().get(objectName)?.getDescribe().fields.getMap();
            Map<String, String> validFields = new Map<String, String>();

            if (fieldsMap != null) {
                for (Schema.SObjectField field : fieldsMap.values()) {
                    Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                    
                    // Exclude calculated fields (formulas), auto-number fields, and read-only fields
                    if (!fieldDescribe.isCalculated() && 
                        !fieldDescribe.isAutoNumber() && 
                        fieldDescribe.isUpdateable()) {
                        
                        validFields.put(fieldDescribe.getName(), fieldDescribe.getLabel());
                    }
                }
            }

            return validFields;
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
            // Validate input parameters
            if (String.isBlank(sObjectApiName)) {
                throw new AuraHandledException('Object API name cannot be empty');
            }
            
            if (String.isBlank(fieldName)) {
                throw new AuraHandledException('Field name cannot be empty');
            }
            
            // Validate object name format
            if (!Pattern.matches('^[a-zA-Z0-9_]+$', sObjectApiName) && 
                !Pattern.matches('^[a-zA-Z0-9_]+__[a-zA-Z0-9_]+$', sObjectApiName) &&
                !Pattern.matches('^[a-zA-Z0-9_]+__[a-zA-Z0-9_]+__[a-zA-Z0-9_]+$', sObjectApiName)) {
                throw new AuraHandledException('Invalid object name format');
            }
            
            // Validate field name format
            if (!Pattern.matches('^[a-zA-Z0-9_]+$', fieldName) && 
                !Pattern.matches('^[a-zA-Z0-9_]+__[a-zA-Z0-9_]+$', fieldName)) {
                throw new AuraHandledException('Invalid field name format');
            }
            
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
            // Input validation
            if (newRecord == null) {
                throw new AuraHandledException('Listener record cannot be null');
            }
            
            if (String.isBlank(newRecord.Flowdometer__Object_Name__c)) {
                throw new AuraHandledException('Object Name is required');
            }
            
            if (String.isBlank(newRecord.Flowdometer__Field_To_Track__c)) {
                throw new AuraHandledException('Field To Track is required');
            }
            
            // ENHANCED DEBUGGING: Log the object and field being tracked
            System.debug(LoggingLevel.INFO, '### FLOWDOMETER: Creating listener for Object=' + 
                        newRecord.Flowdometer__Object_Name__c + ', Field=' + 
                        newRecord.Flowdometer__Field_To_Track__c);
            
            // Check if this is an Order object (which has caused issues)
            if (newRecord.Flowdometer__Object_Name__c == 'Order') {
                System.debug(LoggingLevel.WARN, '### FLOWDOMETER: Creating listener for Order object, which may have performance limitations');
            }
            
            // Check if permissions are sufficient before attempting insert
            if (!Schema.sObjectType.Flowdometer__Listener__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create Listener records.');
            }
            
            // Check if the fields are accessible before attempting to use them
            if (!Schema.sObjectType.Flowdometer__Listener__c.fields.Flowdometer__Object_Name__c.isAccessible() ||
                !Schema.sObjectType.Flowdometer__Listener__c.fields.Flowdometer__Field_To_Track__c.isAccessible()) {
                throw new AuraHandledException('You do not have permission to access required fields on Listener records.');
            }
            
            // ENHANCED DEBUGGING: Verify CPU limits before proceeding with insert
            if (Limits.getCpuTime() > Limits.getLimitCpuTime() * 0.7) {
                String cpuLimitMsg = 'Warning: Approaching CPU limits when creating listener. Current usage: ' + 
                                  Limits.getCpuTime() + '/' + Limits.getLimitCpuTime();
                System.debug(LoggingLevel.WARN, cpuLimitMsg);
                // Store warning in the error message field
                newRecord.Flowdometer__Error_Message__c = cpuLimitMsg;
            }
            
            // Check and log the history tracking status before record creation
            String historyStatus = MetaDataUtilityCls.checkFieldHistoryStatus(
                newRecord.Flowdometer__Object_Name__c,
                newRecord.Flowdometer__Field_To_Track__c
            );
            
            System.debug(LoggingLevel.INFO, '### FLOWDOMETER: History tracking status before insert: ' + historyStatus);
            
            // Log warning/error in error message field if applicable
            if (historyStatus != null && (historyStatus.startsWith('ERROR:') || historyStatus.startsWith('WARNING:'))) {
                newRecord.Flowdometer__Error_Message__c = historyStatus;
            }
            
            // Perform the insert operation
            insert newRecord;
            
            // After insertion, verify history tracking is enabled
            Boolean isHistoryEnabled = false;
            try {
                isHistoryEnabled = MetaDataUtilityCls.checkIfHistoryIsEnabled(
                    newRecord.Flowdometer__Object_Name__c,
                    newRecord.Flowdometer__Field_To_Track__c
                );
                
                System.debug(LoggingLevel.INFO, '### FLOWDOMETER DIAGNOSTIC: After Listener creation, history tracking enabled for ' + 
                    newRecord.Flowdometer__Object_Name__c + '.' + newRecord.Flowdometer__Field_To_Track__c + ': ' + isHistoryEnabled);
                
                if (!isHistoryEnabled) {
                    // History tracking failed, update the error message field
                    String historyErrorMsg = 'Warning: History tracking could not be verified for ' + 
                                          newRecord.Flowdometer__Object_Name__c + '.' + 
                                          newRecord.Flowdometer__Field_To_Track__c;
                    Listener__c listenerToUpdate = new Listener__c(
                        Id = newRecord.Id,
                        Flowdometer__Error_Message__c = historyErrorMsg
                    );
                    update listenerToUpdate;
                    System.debug(LoggingLevel.WARN, historyErrorMsg);
                }
            } catch (Exception histEx) {
                // Don't fail the overall operation if just the verification fails
                String historyErrorMsg = 'Error verifying history tracking: ' + histEx.getMessage();
                System.debug(LoggingLevel.ERROR, historyErrorMsg);
                
                // Update the listener record with the error message
                Listener__c listenerToUpdate = new Listener__c(
                    Id = newRecord.Id,
                    Flowdometer__Error_Message__c = historyErrorMsg
                );
                update listenerToUpdate;
            }
            
            // --- Build friendly labels for lookup fields ----------------------
            Schema.SObjectType trackedObjType = Schema.getGlobalDescribe().get(newRecord.Flowdometer__Object_Name__c);
            String trackedObjectLabel = (trackedObjType != null) ? trackedObjType.getDescribe().getLabel() : newRecord.Flowdometer__Object_Name__c;

            // Fetch the UI label of the tracked field (fallback to API name)
            String trackedFieldLabel;
            if(trackedObjType != null) {
                Map<String,Schema.SObjectField> fldMap = trackedObjType.getDescribe().fields.getMap();
                Schema.SObjectField fld = fldMap.get(newRecord.Flowdometer__Field_To_Track__c.toLowerCase());
                trackedFieldLabel = (fld != null) ? fld.getDescribe().getLabel() : newRecord.Flowdometer__Field_To_Track__c;
            } else {
                trackedFieldLabel = newRecord.Flowdometer__Field_To_Track__c;
            }

            // Friendly labels for the two lookup fields
            String fieldLabelForLookupToFlow   = trackedFieldLabel  + ' Flow';
            String fieldLabelForLookupFromFlow = trackedObjectLabel + ' Record';

            String apiConvertedLabel = MetaDataUtilityCls.convertLabeltoAPIName(fieldLabelForLookupToFlow);
            
            // Check if the field already exists
            Boolean lookupExists = MetaDataUtilityCls.doesFieldExist(newRecord.Flowdometer__Object_Name__c, apiConvertedLabel);
            
            if (!lookupExists) {
                // Enqueue asynchronous lookup creation to avoid mixed DML / callout issue
                System.enqueueJob(
                    new LookupFieldCreator(
                        newRecord.Flowdometer__Object_Name__c,
                        fieldLabelForLookupToFlow,
                        'Flowdometer__Flow__c',
                        newRecord.Id));
            } else {
                System.debug(LoggingLevel.INFO, '### FLOWDOMETER DIAGNOSTIC: Lookup field already exists: ' + 
                           apiConvertedLabel + ' on ' + newRecord.Flowdometer__Object_Name__c);
            }
            
            // Now try to create the lookup from Flow to the tracked object (always allow this)
            String apiLabelFromFlow = MetaDataUtilityCls.convertLabeltoAPIName(fieldLabelForLookupFromFlow);
            
            // Check if this field already exists
            Boolean flowLookupExists = MetaDataUtilityCls.doesFieldExist('Flowdometer__Flow__c', apiLabelFromFlow);
            
            if (!flowLookupExists) {
                // Enqueue the reverse lookup creation
                System.enqueueJob(
                    new LookupFieldCreator(
                        'Flowdometer__Flow__c',
                        fieldLabelForLookupFromFlow,
                        newRecord.Flowdometer__Object_Name__c,
                        newRecord.Id));
            }
            
            // Schedule a check for tracker creation (runs async)
            checkTrackersAfterDelay(newRecord.Id);
            
            return newRecord.Id;
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
            throw new AuraHandledException('Failed to create Listener record: ' + e.getMessage());
        }
    }

    // Helper method to check trackers after a delay (to give flow time to execute)
    @future
    private static void checkTrackersAfterDelay(Id listenerId) {
        try {
            System.debug(LoggingLevel.INFO, 'Checking tracker creation for Listener ID: ' + listenerId);
            
            // Query for the Listener record
            Listener__c listener = [
                SELECT Id, Flowdometer__Object_Name__c, Flowdometer__Field_To_Track__c, Flowdometer__Error_Message__c
                FROM Flowdometer__Listener__c 
                WHERE Id = :listenerId
                LIMIT 1
            ];
            
            // Query for Flow records related to this Listener's target object
            List<Flowdometer__Flow__c> flows = [
                SELECT Id, Name, Flowdometer__Tracked_Object__c 
                FROM Flowdometer__Flow__c 
                WHERE Flowdometer__Tracked_Object__c = :listener.Flowdometer__Object_Name__c
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];
            
            System.debug(LoggingLevel.INFO, 'Found ' + flows.size() + ' flow tracker records for object: ' + 
                        listener.Flowdometer__Object_Name__c);
            
            // Check if any Flow records were created
            if (flows.isEmpty()) {
                // No trackers were created
                String noTrackersMsg = 'Warning: No Flow tracker records were created for this Listener. ' +
                                   'This may indicate an issue with the Flow trigger process.';
                System.debug(LoggingLevel.WARN, noTrackersMsg);
                
                // Update the Listener record with the error message
                listener.Flowdometer__Error_Message__c = noTrackersMsg;
                update listener;
            } else {
                // Trackers were created successfully
                System.debug(LoggingLevel.INFO, 'Flow tracker records were created successfully');
            }
            
            // Query for history fields to verify they're being tracked
            try {
                // Check if history tracking is enabled for the field
                Boolean isHistoryTracked = MetaDataUtilityCls.checkIfHistoryIsEnabled(
                    listener.Flowdometer__Object_Name__c,
                    listener.Flowdometer__Field_To_Track__c
                );
                
                if (!isHistoryTracked) {
                    String historyWarning = 'Warning: History tracking is not enabled for field ' + 
                                         listener.Flowdometer__Field_To_Track__c + ' on object ' + 
                                         listener.Flowdometer__Object_Name__c;
                    System.debug(LoggingLevel.WARN, historyWarning);
                    
                    // Only update if we don't already have a more important error message
                    if (String.isBlank(listener.Flowdometer__Error_Message__c)) {
                        listener.Flowdometer__Error_Message__c = historyWarning;
                        update listener;
                    }
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'Error checking history tracking status: ' + ex.getMessage());
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in checkTrackersAfterDelay: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    // Queueable to perform Metadata callout after DML is committed
    public class LookupFieldCreator implements Queueable, Database.AllowsCallouts {
        String targetObject;
        String fieldLabel;
        String referenceTo;
        Id listenerId;
        public LookupFieldCreator(String tgt, String lbl, String ref, Id lst) {
            targetObject = tgt;
            fieldLabel = lbl;
            referenceTo = ref;
            listenerId = lst;
        }
        public void execute(QueueableContext qc) {
            MetaDataUtilityCls.createLookupField(targetObject, fieldLabel, referenceTo, listenerId);
        }
    }
}
