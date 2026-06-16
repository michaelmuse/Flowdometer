/**
 * @description Controller for listenerMasterConfiguration component
 */
public with sharing class ListenerMasterConfigurationController {
    // FLSGrantJob retry knobs (statics must live on the top-level type).
    @TestVisible private static final Integer FLS_GRANT_MAX_ATTEMPTS = 3;
    private static final Integer FLS_GRANT_RETRY_DELAY_MINUTES = 1;
    // Test seam: enqueueJob is skipped in tests, this records the decision.
    @TestVisible private static Boolean flsGrantRetryScheduled = false;
    
    // Lightweight diagnostics to the debug log only. (An earlier design emailed
    // admins on CRITICAL errors via a placeholder recipient; that default-off,
    // non-functional path was removed to avoid shipping a hardcoded address and
    // an unnecessary OrgWideEmailAddress read.)
    private static void logError(String errorType, String errorMessage, String details) {
        System.debug(LoggingLevel.ERROR, 'Flowdometer Error (' + errorType + '): ' + errorMessage);
        System.debug(LoggingLevel.ERROR, 'Details: ' + details);
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
            throw new AuraHandledException('Unable to load objects. Please try again or contact your administrator.');
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

                    // Exclude long text areas (incl. rich text): Salesforce
                    // field history stores no old/new values for them, so a
                    // listener on one can never produce Steps. Don't offer
                    // fields that can't work. (Plain TextArea <= 255 chars
                    // does carry history values and stays available.)
                    Boolean isLongTextArea =
                        fieldDescribe.getType() == Schema.DisplayType.TEXTAREA &&
                        fieldDescribe.getLength() > 255;

                    // Exclude calculated fields (formulas), auto-number fields, and read-only fields
                    if (!fieldDescribe.isCalculated() && 
                        !fieldDescribe.isAutoNumber() && 
                        fieldDescribe.isUpdateable() &&
                        !isLongTextArea) {
                        
                        validFields.put(fieldDescribe.getName(), fieldDescribe.getLabel());
                    }
                }
            }

            return validFields;
        } catch (CalloutException ce) {
            System.debug(LoggingLevel.ERROR, 'Callout error: ' + ce.getMessage() + '\n' + ce.getStackTraceString());
            throw new AuraHandledException('The request timed out. Please try again later.');
        } catch (AuraHandledException ahe) {
            // Preserve intentional user-facing validation messages.
            throw ahe;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error getting fields: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Unable to load fields for the selected object. Please try again or contact your administrator.');
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
                !sObjectApiName.startsWith('')) {
                
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
            
            if (String.isBlank(newRecord.Object_Name__c)) {
                throw new AuraHandledException('Object Name is required');
            }
            
            if (String.isBlank(newRecord.Field_To_Track__c)) {
                throw new AuraHandledException('Field To Track is required');
            }
            
            // ENHANCED DEBUGGING: Log the object and field being tracked
            System.debug(LoggingLevel.INFO, '### FLOWDOMETER: Creating listener for Object=' + 
                        newRecord.Object_Name__c + ', Field=' + 
                        newRecord.Field_To_Track__c);
            
            // Check if this is an Order object (which has caused issues)
            if (newRecord.Object_Name__c == 'Order') {
                System.debug(LoggingLevel.WARN, '### FLOWDOMETER: Creating listener for Order object, which may have performance limitations');
            }
            
            // Check if permissions are sufficient before attempting insert
            if (!Schema.sObjectType.Listener__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create Listener records.');
            }
            
            // Check if the fields are accessible and createable before attempting to use them
            // Note: In test context, we skip this check because the running test user may not have
            // the package permission set assigned. The running user (system admin) has access to all fields.
            if (!Test.isRunningTest()) {
                if (!Schema.sObjectType.Listener__c.fields.Object_Name__c.isAccessible() ||
                    !Schema.sObjectType.Listener__c.fields.Field_To_Track__c.isAccessible() ||
                    !Schema.sObjectType.Listener__c.fields.Object_Name__c.isCreateable() ||
                    !Schema.sObjectType.Listener__c.fields.Field_To_Track__c.isCreateable() ||
                    !Schema.sObjectType.Listener__c.fields.Error_Message__c.isCreateable()) {
                    throw new AuraHandledException('You do not have permission to access or modify required fields on Listener records.');
                }
            }
            
            // ENHANCED DEBUGGING: Verify CPU limits before proceeding with insert
            if (Limits.getCpuTime() > Limits.getLimitCpuTime() * 0.7) {
                String cpuLimitMsg = 'Warning: Approaching CPU limits when creating listener. Current usage: ' + 
                                  Limits.getCpuTime() + '/' + Limits.getLimitCpuTime();
                System.debug(LoggingLevel.WARN, cpuLimitMsg);
                // Store warning in the error message field
                if (Schema.sObjectType.Listener__c.fields.Error_Message__c.isCreateable()) {
                    newRecord.Error_Message__c = cpuLimitMsg;
                }
            }
            
            // Check and log the history tracking status before record creation
            String historyStatus = MetaDataUtilityCls.checkFieldHistoryStatus(
                newRecord.Object_Name__c,
                newRecord.Field_To_Track__c
            );
            
            System.debug(LoggingLevel.INFO, '### FLOWDOMETER: History tracking status before insert: ' + historyStatus);
            
            // Log warning/error in error message field if applicable
            if (historyStatus != null && (historyStatus.startsWith('ERROR:') || historyStatus.startsWith('WARNING:'))) {
                if (Schema.sObjectType.Listener__c.fields.Error_Message__c.isCreateable()) {
                    newRecord.Error_Message__c = historyStatus;
                }
            }
            
            // Perform the insert operation
            insert newRecord;
            
            // After insertion, verify history tracking is enabled
            Boolean isHistoryEnabled = false;
            try {
                isHistoryEnabled = MetaDataUtilityCls.checkIfHistoryIsEnabled(
                    newRecord.Object_Name__c,
                    newRecord.Field_To_Track__c
                );
                
                System.debug(LoggingLevel.INFO, '### FLOWDOMETER DIAGNOSTIC: After Listener creation, history tracking enabled for ' + 
                    newRecord.Object_Name__c + '.' + newRecord.Field_To_Track__c + ': ' + isHistoryEnabled);
                
                if (!isHistoryEnabled) {
                    // History tracking is not enabled
                    // Check if we already have a detailed warning message from checkFieldHistoryStatus
                    String historyErrorMsg;
                    if (historyStatus != null && historyStatus.startsWith('WARNING:')) {
                        // Use the detailed message from checkFieldHistoryStatus which includes instructions
                        historyErrorMsg = historyStatus;
                    } else {
                        // Fallback to generic message if no detailed message was provided
                        historyErrorMsg = 'Warning: History tracking could not be verified for ' + 
                                      newRecord.Object_Name__c + '.' + 
                                      newRecord.Field_To_Track__c + 
                                      '. Please enable field history tracking manually in Setup > Object Manager > ' +
                                      newRecord.Object_Name__c + ' > Fields & Relationships > Set History Tracking.';
                    }
                    
                    // Check if we have permission to update the error message field
                    if (Schema.sObjectType.Listener__c.fields.Error_Message__c.isUpdateable()) {
                        Listener__c listenerToUpdate = new Listener__c(
                            Id = newRecord.Id,
                            Error_Message__c = historyErrorMsg
                        );
                        update listenerToUpdate;
                    }
                    System.debug(LoggingLevel.WARN, historyErrorMsg);
                }
            } catch (Exception histEx) {
                // Don't fail the overall operation if just the verification fails
                String historyErrorMsg = 'Error verifying history tracking: ' + histEx.getMessage();
                System.debug(LoggingLevel.ERROR, historyErrorMsg);
                
                // Check if we have permission to update the error message field
                if (Schema.sObjectType.Listener__c.fields.Error_Message__c.isUpdateable()) {
                    // Update the listener record with the error message
                    Listener__c listenerToUpdate = new Listener__c(
                        Id = newRecord.Id,
                        Error_Message__c = historyErrorMsg
                    );
                    update listenerToUpdate;
                }
            }
            
            // --- Build friendly labels for lookup fields ----------------------
            Schema.SObjectType trackedObjType = Schema.getGlobalDescribe().get(newRecord.Object_Name__c);
            String trackedObjectLabel = (trackedObjType != null) ? trackedObjType.getDescribe().getLabel() : newRecord.Object_Name__c;

            // Fetch the UI label of the tracked field (fallback to API name)
            String trackedFieldLabel;
            if(trackedObjType != null) {
                Map<String,Schema.SObjectField> fldMap = trackedObjType.getDescribe().fields.getMap();
                Schema.SObjectField fld = fldMap.get(newRecord.Field_To_Track__c.toLowerCase());
                trackedFieldLabel = (fld != null) ? fld.getDescribe().getLabel() : newRecord.Field_To_Track__c;
            } else {
                trackedFieldLabel = newRecord.Field_To_Track__c;
            }

            // Friendly labels for the two lookup fields
            String fieldLabelForLookupToFlow   = trackedFieldLabel  + ' Flow';
            String fieldLabelForLookupFromFlow = trackedObjectLabel;

            String flowObjectApi = Flow__c.SObjectType.getDescribe().getName();

            String apiConvertedLabel = MetaDataUtilityCls.convertLabeltoAPIName(fieldLabelForLookupToFlow);
            
            // Check if the field already exists
            Boolean lookupExists = MetaDataUtilityCls.doesFieldExist(newRecord.Object_Name__c, apiConvertedLabel);
            
            if (!lookupExists) {
                // Enqueue asynchronous lookup creation to avoid mixed DML / callout issue
                System.enqueueJob(
                    new LookupFieldCreator(
                        newRecord.Object_Name__c,
                        fieldLabelForLookupToFlow,
                        flowObjectApi,
                        newRecord.Id));
            } else {
                System.debug(LoggingLevel.INFO, '### FLOWDOMETER DIAGNOSTIC: Lookup field already exists: ' + 
                           apiConvertedLabel + ' on ' + newRecord.Object_Name__c);
            }
            
            // Now try to create the lookup from Flow to the tracked object (always allow this)
            String apiLabelFromFlow = MetaDataUtilityCls.convertLabeltoAPIName(fieldLabelForLookupFromFlow);
            
            // Check if this field already exists
            Boolean flowLookupExists = MetaDataUtilityCls.doesFieldExist(flowObjectApi, apiLabelFromFlow);
            
            if (!flowLookupExists) {
                // Enqueue the reverse lookup creation
                System.enqueueJob(
                    new LookupFieldCreator(
                        flowObjectApi,
                        fieldLabelForLookupFromFlow,
                        newRecord.Object_Name__c,
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
            
            // Ensure Listener__c fields are readable before querying
            if (!Schema.sObjectType.Listener__c.isAccessible() ||
                !Schema.sObjectType.Listener__c.fields.Object_Name__c.isAccessible() ||
                !Schema.sObjectType.Listener__c.fields.Field_To_Track__c.isAccessible() ||
                !Schema.sObjectType.Listener__c.fields.Error_Message__c.isAccessible() ||
                !Schema.sObjectType.Listener__c.fields.Enable_History__c.isAccessible()) {
                System.debug(LoggingLevel.WARN, 'Insufficient access to Listener fields; skipping tracker check for ' + listenerId);
                return;
            }

            // Query for the Listener record - include Enable_History__c to check toggle state
            Listener__c listener = [
                SELECT Id, Object_Name__c, Field_To_Track__c, 
                       Error_Message__c, Enable_History__c
                FROM Listener__c 
                WHERE Id = :listenerId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            // If Enable_History__c is false, Flow tracker records won't be created (by design)
            // This is expected behavior - skip the warning check
            if (listener.Enable_History__c == false) {
                System.debug(LoggingLevel.INFO, 'Enable_History__c is disabled for Listener ' + listenerId + 
                            '. Flow tracker records will not be created until history tracking is enabled. This is expected behavior.');
                return; // Exit early - no warning needed
            }
            
            // Ensure Flow__c fields are readable before querying
            if (!Schema.sObjectType.Flow__c.isAccessible() ||
                !Schema.sObjectType.Flow__c.fields.Name.isAccessible() ||
                !Schema.sObjectType.Flow__c.fields.Tracked_Object__c.isAccessible()) {
                System.debug(LoggingLevel.WARN, 'Insufficient access to Flow__c fields; skipping flow tracker verification.');
                return;
            }

            // Query for Flow records related to this Listener's target object
            List<Flow__c> flows = [
                SELECT Id, Name, Tracked_Object__c 
                FROM Flow__c 
                WHERE Tracked_Object__c = :listener.Object_Name__c
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];
            
            System.debug(LoggingLevel.INFO, 'Found ' + flows.size() + ' flow tracker records for object: ' + 
                        listener.Object_Name__c);
            
            // Check if any Flow records were created
            if (flows.isEmpty()) {
                // No trackers were created
                String noTrackersMsg = 'Warning: No Flow tracker records were created for this Listener. ' +
                                   'This may indicate an issue with the Flow trigger process.';
                System.debug(LoggingLevel.WARN, noTrackersMsg);
                
                // Update the Listener record with the error message
                if (Schema.sObjectType.Listener__c.fields.Error_Message__c.isUpdateable()) {
                    listener.Error_Message__c = noTrackersMsg;
                }
                update listener;
            } else {
                // Trackers were created successfully
                System.debug(LoggingLevel.INFO, 'Flow tracker records were created successfully');
            }
            
            // Query for history fields to verify they're being tracked
            try {
                // Check if history tracking is enabled for the field
                Boolean isHistoryTracked = MetaDataUtilityCls.checkIfHistoryIsEnabled(
                    listener.Object_Name__c,
                    listener.Field_To_Track__c
                );
                
                if (!isHistoryTracked) {
                    String historyWarning = 'Warning: History tracking is not enabled for field ' + 
                                         listener.Field_To_Track__c + ' on object ' + 
                                         listener.Object_Name__c;
                    System.debug(LoggingLevel.WARN, historyWarning);
                    
                    // Only update if we don't already have a more important error message
                    if (String.isBlank(listener.Error_Message__c)) {
                        if (Schema.sObjectType.Listener__c.fields.Error_Message__c.isUpdateable()) {
                            listener.Error_Message__c = historyWarning;
                        }
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
    public inherited sharing class LookupFieldCreator implements Queueable, Database.AllowsCallouts {
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
            String errorMessage = null;
            
            try {
                String fieldAPIName = MetaDataUtilityCls.convertLabeltoAPIName(fieldLabel);
                if (MetaDataUtilityCls.doesFieldExist(targetObject, fieldAPIName)) {
                    MetaDataUtilityCls.grantFieldAccessWithDml(targetObject, fieldAPIName);
                    System.debug(LoggingLevel.INFO, 'Field ' + fieldAPIName + ' already exists on ' + targetObject + ', skipping creation');
                    return;
                }
                
                Map<String, String> result = MetaDataUtilityCls.createLookupField(targetObject, fieldLabel, referenceTo, listenerId);
                
                if (result != null && result.get('success') != 'true') {
                    errorMessage = 'Failed to create lookup field ' + fieldAPIName + ' on ' + targetObject + 
                                 ': ' + (result.get('message') != null && result.get('message') != ''
                                 ? result.get('message')
                                 : 'Unknown error');
                    System.debug(LoggingLevel.ERROR, errorMessage);
                } else {
                    System.debug(LoggingLevel.INFO, 'Successfully created lookup field ' + fieldAPIName + ' on ' + targetObject);

                    // Chain a separate Queueable to grant FLS. The Tooling API field
                    // creation completes via HTTP but the field metadata hasn't propagated
                    // to the FieldPermissions subsystem yet in this transaction. Running
                    // the FLS grant in a chained Queueable gives the platform time to
                    // commit the field before the FieldPermissions DML runs.
                    if (!Test.isRunningTest()) {
                        System.enqueueJob(new FLSGrantJob(targetObject, fieldAPIName));
                    }
                }
            } catch (Exception e) {
                errorMessage = 'Exception creating lookup field ' + fieldLabel + ' on ' + targetObject + 
                             ': ' + e.getMessage();
                System.debug(LoggingLevel.ERROR, errorMessage);
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }
            
            if (errorMessage != null && listenerId != null) {
                try {
                    if (Schema.sObjectType.Listener__c.fields.Error_Message__c.isUpdateable()) {
                        Listener__c listenerToUpdate = new Listener__c(
                            Id = listenerId,
                            Error_Message__c = errorMessage
                        );
                        update listenerToUpdate;
                        System.debug(LoggingLevel.INFO, 'Updated Listener record with error message: ' + errorMessage);
                    }
                } catch (Exception updateEx) {
                    System.debug(LoggingLevel.ERROR, 'Failed to update Listener record with error message: ' + updateEx.getMessage());
                }
            }
        }
    }

    public inherited sharing class FLSGrantJob implements Queueable {
        // A Tooling-created field can take longer than one queueable hop to
        // propagate to the FieldPermissions subsystem; when that race is lost
        // the grant fails silently and the field stays FLS-invisible until the
        // setup-screen reconciler next runs - which a user who creates one
        // listener and never returns would never trigger. Retry with a delay
        // so the grant lands unattended. The grant is idempotent, so retrying
        // is safe.
        String objectApiName;
        String fieldApiName;
        Integer attempt;
        public FLSGrantJob(String obj, String fld) {
            this(obj, fld, 1);
        }
        @TestVisible
        private FLSGrantJob(String obj, String fld, Integer attemptNumber) {
            objectApiName = obj;
            fieldApiName = fld;
            attempt = attemptNumber;
        }
        public void execute(QueueableContext qc) {
            Boolean granted = MetaDataUtilityCls.grantFieldAccessWithDml(objectApiName, fieldApiName);
            System.debug(LoggingLevel.INFO,
                'FLSGrantJob: grantFieldAccessWithDml(' + objectApiName + ', ' + fieldApiName +
                ') returned ' + granted + ' (attempt ' + attempt + ' of ' + FLS_GRANT_MAX_ATTEMPTS + ')');
            if (!granted && attempt < FLS_GRANT_MAX_ATTEMPTS) {
                flsGrantRetryScheduled = true;
                if (!Test.isRunningTest()) {
                    System.enqueueJob(
                        new FLSGrantJob(objectApiName, fieldApiName, attempt + 1),
                        FLS_GRANT_RETRY_DELAY_MINUTES
                    );
                }
            }
        }
    }
}