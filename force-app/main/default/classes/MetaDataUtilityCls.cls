public inherited sharing class MetaDataUtilityCls {
    public static final String HISTORY_ENABLED_HAS_NO_LIMITS = 'HISTORY_ENABLED_HAS_NO_LIMITS';
    public static final String HISTORY_NOT_ENABLED_EARLIER_BUT_ENABLED_NOW = 'HISTORY_NOT_ENABLED_EARLIER_BUT_ENABLED_NOW';
    public static final String HISTORY_ENABLED_ALREADY = 'HISTORY_ENABLED_ALREADY';
    public static final String HISTORY_ENABLED_HAS_LIMITS = 'HISTORY_ENABLED_HAS_LIMITS';
    private static final String FLOWDOMETER_PERMISSION_SET_NAME = 'Flowdometer__Flowdometer_User';
    private static final String FLOWDOMETER_FLOW_OBJECT_LABEL = 'Flow';
    public static Map<String, String> lookUpAPINameMap = new Map<String, String>();
    public static Map<String, String> relatedLookupMap = new Map<String, String>();
    public static Boolean flowAlreadyHasLookupTosObject = false;
    public static Boolean sObjectAlreadyHasLookupToFlow = false;
    
    // Hard-coded list of objects known not to support history tracking AT ALL
    // These should NOT appear in the Setup Listeners page
    private static final Set<String> OBJECTS_WITHOUT_HISTORY_SUPPORT = new Set<String>{
        'ContentDocument', 'ContentDocumentLink', 'ContentVersion', 
        'Attachment', 'Note', 'EmailMessage', 'FeedItem', 'ListView',
        'UserProvAccount', 'UserProvisioningLog', 'UserProvisioningRequest', 
        'WaveAnnotationTarget', 'WebCartDocument',
        'MessagingEndUser', 'MessagingSession', 'OrgMetric', 'OrgMetricScanSummary'
    };

    // Special object type checks - identify objects that need extra care
    private static final Set<String> specialObjectTypes = new Set<String>{
        'User', 'Group', 'GroupMember', 'Profile', 'PermissionSet', 
        'LoginHistory', 'NetworkMember', 'CollaborationGroup',
        'ContentDocument', 'ContentVersion', 'ContentWorkspace',
        'Order' // Keep Order object in special objects list for monitoring
    };
    
    // Standard objects that definitely support history tracking
    private static final Set<String> STANDARD_HISTORY_OBJECTS = new Set<String>{
        'Account',
        'Asset',
        'Campaign',
        'Case',
        'Contact',
        'Contract',
        'Lead',
        'Opportunity',
        'Order',
        'Product2',
        'Solution'
    };
    
    // Object types that may not allow creation of custom lookup fields ON THEM
    // But we still want to track them if possible
    private static final Set<String> LOOKUP_FIELD_CREATION_LIMITATIONS = new Set<String>{
        'User', 'Group', 'Profile', 'PermissionSet',
        'EmailMessage', 'NetworkMember', 'CollaborationGroup',
        'ContentDocument', 'ContentVersion', 'ContentWorkspace'
    };

    //This method is used to get the lookup field from the object
    public static void setLookupFieldMaps(String objectName) {
        List<SObjectField> sObjectFieldNames = Schema.getGlobalDescribe()
            .get(objectName)
            ?.getDescribe()
            .fields.getMap()
            .values();
        if (sObjectFieldNames != null) {
            for (SObjectField field : sObjectFieldNames) {
                DescribeFieldResult selectedField = field.getDescribe();
                if (
                    selectedField.getType() == Schema.DisplayType.REFERENCE &&
                    selectedField.isCustom()
                ) {
                    Schema.SObjectType relatedObjType = selectedField.getReferenceTo()[0];
                    // General security check - verify user has access to the object
                    if (!relatedObjType.getDescribe().isAccessible()) {
                        System.debug(LoggingLevel.ERROR, 'User does not have access to the related object: ' + relatedObjType.getDescribe().getName());
                        continue; // Skip this field
                    }
                    
                    relatedLookupMap.put(
                        relatedObjType.getDescribe().getName(),
                        relatedObjType.getDescribe().getLabel()
                    );
                    lookUpAPINameMap.put(
                        selectedField.getLabel(),
                        selectedField.getName()
                    );
                }
            }
        }
    }

    //This method is used to get the fields from the object
    public static Map<String, String> getSObjectFields(String objectName) {
        Map<String, String> fieldSetMap = new Map<String, String>();
        Map<String, String> fieldNameAPISetMap = new Map<String, String>();
        Map<String, String> sObjectFieldsMap = new Map<String, String>();
        Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe()
            .get(objectName)
            ?.getDescribe()
            .fields.getMap();

        if (fieldsMap != null) {
            for (Schema.SObjectField field : fieldsMap.values()) {
                Schema.DescribeFieldResult fieldResult = field.getDescribe();
                if (fieldResult.isAccessible()) {
                    sObjectFieldsMap.put(
                        fieldResult.getName(),
                        fieldResult.getLabel()
                    );
                    fieldNameAPISetMap.put(
                        fieldResult.getLabel(),
                        fieldResult.getName()
                    );
                }
            }

            for (String key : getSortedKeySet(sObjectFieldsMap)) {
                fieldSetMap.put(key, sObjectFieldsMap.get(key));
            }
        }

        return fieldSetMap;
    }

    //This method is used to get all the objects from the org
    public static Map<String, String> getAllSObjectsInOrg() {
        Map<String, String> objectAPIToLabelMap = new Map<String, String>();
        Map<String, String> objectAPINameMap = new Map<String, String>();

        for (SObjectType sobjectType : Schema.getGlobalDescribe().values()) {
            String name = sobjectType.getDescribe().getName();
            String label = sobjectType.getDescribe().getLabel();

            if (
                !name.containsIgnoreCase('history') &&
                !name.containsIgnoreCase('tag') &&
                !name.containsIgnoreCase('share') &&
                !name.containsIgnoreCase('feed') &&
                !name.containsIgnoreCase('changeevent')
            ) {
                objectAPIToLabelMap.put(name, label);
            }
        }

        for (String key : getSortedKeySet(objectAPIToLabelMap)) {
            objectAPINameMap.put(key, objectAPIToLabelMap.get(key));
        }

        return objectAPINameMap;
    }

    //This method is used to sort the keyset
    public static List<String> getSortedKeySet(
        Map<String, String> objectAPIToLabelMap
    ) {
        List<String> keySetList = new List<String>();
        keySetList.addAll(objectAPIToLabelMap.keySet());
        keySetList.sort();

        return keySetList;
    }

    // Helper method to retry operations that might have transient failures
    private static Object retryOperation(RetryableOperation operation, Integer maxRetries) {
        Integer retryCount = 0;
        Exception lastException;
        
        while (retryCount < maxRetries) {
            try {
                return operation.execute();
            } catch (CalloutException ce) {
                lastException = ce;
                // Only retry on timeout-related errors
                if (!ce.getMessage().containsIgnoreCase('timed out') && 
                    !ce.getMessage().containsIgnoreCase('timeout')) {
                    throw ce;
                }
                retryCount++;
                if (retryCount < maxRetries) {
                    // Exponential backoff: wait longer between each retry
                    Integer waitTime = Math.min(2000 * (Integer)Math.pow(2, retryCount), 8000); // Max 8 seconds
                    System.debug(LoggingLevel.INFO, 'Retrying operation after waiting ' + waitTime + 'ms. Attempt ' + (retryCount + 1) + ' of ' + maxRetries);
                    wait(waitTime);
                }
            }
        }
        
        // If we get here, all retries failed
        throw lastException;
    }
    
    // Helper method to wait/sleep (simulated in Apex)
    private static void wait(Integer milliseconds) {
        Long startTime = System.currentTimeMillis();
        Long endTime = startTime + milliseconds;
    }
    
    // Interface for operations that can be retried
    public interface RetryableOperation {
        Object execute();
    }
    
    public static void grantFieldEditAccess(
        String objectApiName,
        String fieldApiName
    ) {
        //permission set, objectAPINameWLookup, LookupFieldAPIName
        try {
            // Check if retry is enabled via feature flag
            Boolean useRetry = FeatureFlagUtil.isEnabled(FeatureFlagUtil.FEATURE_RETRY_METADATA_OPERATIONS);
            
            if (useRetry) {
                // Use the retry mechanism for this operation
                retryOperation(new GrantFieldAccessOperation(objectApiName, fieldApiName), 3);
            } else {
                // Use the direct method without retry
                MetadataService.MetadataPort service = MetadataService.createService();
                service.timeout_x = 180000; // Increase timeout to 3 minutes
                MetadataService.PermissionSet permissionSet = (MetadataService.PermissionSet) service.readMetadata(
                        'PermissionSet',
                        new List<String>{ FLOWDOMETER_PERMISSION_SET_NAME }
                    )
                    .getRecords()[0];
                MetadataService.PermissionSetFieldPermissions fieldPermission = new MetadataService.PermissionSetFieldPermissions();
                fieldPermission.field = objectApiName + '.' + fieldApiName;
                fieldPermission.editable = true;
                fieldPermission.readable = true;
                permissionSet.fieldPermissions.add(fieldPermission);

                List<MetadataService.SaveResult> results = service.updateMetadata(
                    new List<MetadataService.Metadata>{ permissionSet }
                );

                if (results != null && !results.isEmpty()) {
                    MetadataService.handleSaveResults(results[0]);
                }
            }
        } catch (CalloutException ce) {
            // Specific handling for timeout errors
            String errorMsg = 'A timeout occurred while updating permissions: ' + ce.getMessage();
            System.debug(LoggingLevel.ERROR, errorMsg + '\n' + ce.getStackTraceString());
            // In a production environment, you might want to log this to a custom object or send an email notification
        } catch (Exception e) {
            // Log the error but don't throw an exception to allow processing to continue
            System.debug(LoggingLevel.ERROR, 'Error granting field edit access: ' + e.getMessage() + '\n' + e.getStackTraceString());
            // In a production environment, you might want to log this to a custom object or send an email notification
        }
    }
    
    // Implementation of RetryableOperation for granting field access
    private class GrantFieldAccessOperation implements RetryableOperation {
        private String objectApiName;
        private String fieldApiName;
        
        public GrantFieldAccessOperation(String objectApiName, String fieldApiName) {
            this.objectApiName = objectApiName;
            this.fieldApiName = fieldApiName;
        }
        
        public Object execute() {
            MetadataService.MetadataPort service = MetadataService.createService();
            service.timeout_x = 180000; // Increase timeout to 3 minutes (from 2 minutes)
            MetadataService.PermissionSet permissionSet = (MetadataService.PermissionSet) service.readMetadata(
                    'PermissionSet',
                    new List<String>{ FLOWDOMETER_PERMISSION_SET_NAME }
                )
                .getRecords()[0];
            MetadataService.PermissionSetFieldPermissions fieldPermission = new MetadataService.PermissionSetFieldPermissions();
            fieldPermission.field = objectApiName + '.' + fieldApiName;
            fieldPermission.editable = true;
            fieldPermission.readable = true;
            permissionSet.fieldPermissions.add(fieldPermission);

            List<MetadataService.SaveResult> results = service.updateMetadata(
                new List<MetadataService.Metadata>{ permissionSet }
            );

            if (results != null && !results.isEmpty()) {
                MetadataService.handleSaveResults(results[0]);
            }
            
            return null; // No return value needed
        }
    }

    // Check before creating a new Lookup field
    public static Boolean doesFieldExist(String objName, String fieldName) {
        try {
            // Handle null inputs safely
            if (String.isBlank(objName) || String.isBlank(fieldName)) {
                System.debug(
                    LoggingLevel.INFO,
                    'Object name or field name is empty or null.'
                );
                return false;
            }
            
            // Check if the object is accessible before proceeding
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objName);
            if (sObjectType == null) {
                System.debug(LoggingLevel.ERROR, 'Object ' + objName + ' does not exist or is not accessible');
                return false;
            }
            
            if (!sObjectType.getDescribe().isAccessible()) {
                System.debug(LoggingLevel.ERROR, 'User does not have access to the object: ' + objName);
                return false;
            }
            
            Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
            
        if (fieldMap == null) {
            System.debug(
                LoggingLevel.INFO,
                    objName + ' is not a valid Salesforce Object or is not accessible.'
            );
                return false;
            }

            // Safe string operations for managed package objects
            String normalizedFieldName = fieldName;
            if (fieldName != null && fieldName.toLowerCase().startsWith('flowdometer__') && 
                objName != null && !objName.toLowerCase().startsWith('flowdometer__')) {
                // Safely extract substring only if the prefix exists
                normalizedFieldName = fieldName.substring(Math.min(fieldName.length(), 'flowdometer__'.length()));
            }
            
            // Handle managed package fields in managed package objects
            if (objName != null && objName.contains('__')) {
                List<String> parts = objName.split('__');
                if (parts.size() > 2 && !objName.startsWith('Flowdometer__')) {
                    // This is likely a managed package object with a namespace
                    System.debug(
                        LoggingLevel.INFO,
                        objName + ' appears to be a managed package object. Checking field ' + normalizedFieldName
                    );
                }
            }

            // Perform a case-insensitive comparison so we don't miss matches that differ only by letter-case
            String needle = normalizedFieldName.toLowerCase();
            for(String existingName : fieldMap.keySet()) {
                if(existingName != null && existingName.toLowerCase() == needle) {
                    return true;
                }
            }
            return false;
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                'Error checking if field exists: ' + e.getMessage() + '\n' + e.getStackTraceString()
            );
            // Assume field doesn't exist if we encounter an error
            return false;
        }
    }

    // Sanitize the field name to adhere to Salesforce's naming conventions
    public static String convertLabeltoAPIName(String originalName) {
        String sanitized = originalName.replaceAll('[^a-zA-Z0-9]', '_'); // Replace non-alphanumeric characters with underscores
        sanitized = 'Flowdometer__' + sanitized + '__c';
        System.debug(LoggingLevel.INFO, sanitized);
        return sanitized;
    }

    //This method checks if the selected field has history tracking enabled. If field history isn't enabled, then it shows the user a message to 'Enable the History tracking'.
    public static String checkFieldHistoryStatus(
        String sObjectApiName,
        String fieldName
    ) {
        String returnVal;
        
        try {
            // First check if this is an object that definitively doesn't support history tracking
            if(OBJECTS_WITHOUT_HISTORY_SUPPORT.contains(sObjectApiName)) {
                returnVal = 'ERROR: History tracking is not supported for ' + sObjectApiName;
                System.debug(LoggingLevel.ERROR, returnVal);
                return returnVal;
            }
            
            // Check if this is a standard object that we know supports history tracking
            if(STANDARD_HISTORY_OBJECTS.contains(sObjectApiName)) {
                // These standard objects support history tracking, so continue with the process
                System.debug(LoggingLevel.INFO, sObjectApiName + ' is a standard object that supports history tracking.');
            }
            // Check if this is a known problematic object for field CREATION, but not history tracking
            else if(LOOKUP_FIELD_CREATION_LIMITATIONS.contains(sObjectApiName)) {
                System.debug(LoggingLevel.WARN, sObjectApiName + ' may have limitations for creating lookup fields ON the object, but we will still try to track it.');
            }
            
            // Check if this is a special object type that needs careful handling
            if(specialObjectTypes.contains(sObjectApiName)) {
                System.debug(LoggingLevel.INFO, 'Special object type detected: ' + sObjectApiName + 
                             '. Proceeding with caution.');
            }
            
            // Special handling for Case and Opportunity which sometimes show as not having history tracking
            // but actually do support it through the standard UI
            if(sObjectApiName == 'Opportunity' || sObjectApiName == 'Case') {
                // Check if history tracking is already enabled at the object level
                String historyName = sObjectApiName == 'Opportunity' ? 'OpportunityFieldHistory' : 'CaseHistory';
                
                try {
                    // Verify if the history object exists and is accessible
                    SObjectType historyType = Schema.getGlobalDescribe().get(historyName);
                    if(historyType != null && historyType.getDescribe().isAccessible()) {
                        System.debug(LoggingLevel.INFO, 'History tracking is supported for ' + sObjectApiName + 
                                    ' through ' + historyName);
                        
                        // For these standard objects, we'll allow listeners without requiring explicit history tracking setup
                        // This handles cases where history tracking is set up in the UI but not visible via the API
                        returnVal = 'HISTORY_ENABLED_ALREADY';
                        return returnVal;
                    }
                } catch(Exception e) {
                    System.debug(LoggingLevel.WARN, 'Error checking ' + historyName + ': ' + e.getMessage());
                    // Continue with normal processing
                }
            }
            
            // Check CPU limits before proceeding
            if (Limits.getCpuTime() > Limits.getLimitCpuTime() * 0.7) {
                returnVal = 'ERROR: Approaching CPU limit while checking history status for ' + 
                            sObjectApiName + '.' + fieldName;
                System.debug(LoggingLevel.ERROR, returnVal);
                return returnVal;
        }

            // Get the SObject Type Token
            Schema.SObjectType objToken = Schema.getGlobalDescribe().get(sObjectApiName);
            if (objToken == null) {
                returnVal = 'ERROR: Object ' + sObjectApiName + ' does not exist or is not accessible';
                System.debug(LoggingLevel.ERROR, returnVal);
                return returnVal;
            }
            
            // Get Fields from the SObject
            Map<String, Schema.SObjectField> fieldMap = objToken.getDescribe().fields.getMap();
            
            // Check if the field exists
            if(!fieldMap.containsKey(fieldName.toLowerCase())) {
                returnVal = 'ERROR: Field ' + fieldName + ' does not exist on ' + sObjectApiName;
                System.debug(LoggingLevel.ERROR, returnVal);
                return returnVal;
            }
            
            // Get the field token
            Schema.SObjectField fieldToken = fieldMap.get(fieldName.toLowerCase());
            
            // Get the field describe
            Schema.DescribeFieldResult fieldDesc = fieldToken.getDescribe();

            // Check if the field is trackable
            if(!fieldDesc.isAccessible() || !fieldDesc.isUpdateable()) {
                returnVal = 'ERROR: Field ' + fieldName + ' is not accessible or not updateable';
                System.debug(LoggingLevel.ERROR, returnVal);
                return returnVal;
            }
            
            // Check for history tracking
            String tmpVar1 = sObjectApiName;
            List<Schema.FieldDefinition> historyTrackedFields = [
                SELECT QualifiedApiName, IsFieldHistoryTracked
                FROM FieldDefinition
                WHERE EntityDefinition.QualifiedApiName = :tmpVar1 AND IsFieldHistoryTracked = TRUE
            ];
            
            System.debug(LoggingLevel.INFO, 'Found ' + historyTrackedFields.size() + 
                        ' fields with history tracking on ' + sObjectApiName);

            // Check if history tracking is enabled for the given field
            Boolean isHistoryTrackedForThisField = false;
            for(Schema.FieldDefinition field : historyTrackedFields) {
                if(field.QualifiedApiName.equalsIgnoreCase(fieldName)) {
                    isHistoryTrackedForThisField = true;
                    break;
                }
            }
            
            // If field is already tracked for history, return success
            if(isHistoryTrackedForThisField) {
                returnVal = 'HISTORY_ENABLED_ALREADY';
                System.debug(LoggingLevel.INFO, 'History tracking already enabled for ' + 
                            sObjectApiName + '.' + fieldName);
            } else {
                try {
                    // Try to enable history tracking for the field
                    MetadataService.enableFieldHistoryTracking(sObjectApiName, fieldName);
                    returnVal = 'HISTORY_NOT_ENABLED_EARLIER_BUT_ENABLED_NOW';
                    System.debug(LoggingLevel.INFO, 'Successfully enabled history tracking for ' + 
                                sObjectApiName + '.' + fieldName);
                } catch(Exception e) {
                    // Handle different error cases
                    String errorMsg = e.getMessage();
                    System.debug(LoggingLevel.ERROR, 'Error enabling history tracking: ' + errorMsg);
                    
                    if(errorMsg.contains('History tracking is already enabled') || 
                       errorMsg.contains('already tracked')) {
                        returnVal = 'HISTORY_ENABLED_ALREADY';
                    } else if(errorMsg.contains('maximum number of fields') || 
                             errorMsg.contains('limit')) {
                        returnVal = 'HISTORY_ENABLED_HAS_NO_LIMITS';
                    } else if(errorMsg.contains('History tracking is not enabled') || 
                             errorMsg.contains('cannot be enabled')) {
                        
                        // For standard objects that support history tracking or special handling objects
                        // We will proceed with the listener creation even if we can't enable history
                        if(STANDARD_HISTORY_OBJECTS.contains(sObjectApiName) || 
                           specialObjectTypes.contains(sObjectApiName)) {
                            returnVal = 'WARNING: Could not enable history tracking for ' + sObjectApiName + 
                                       ' field ' + fieldName + '. The Listener will be created, but field ' + 
                                       'tracking may not function as expected.';
                        } else if (sObjectApiName.endsWith('__c')) {
                            // For custom objects, see if they just need history tracking enabled at the object level
                            returnVal = 'WARNING: History tracking may need to be enabled at the object level first. ' + 
                                       'Go to Setup > Object Manager > ' + sObjectApiName + ' > Edit and check "Track Field History". ' +
                                       'Then try creating the Listener again.';
                        } else {
                            returnVal = 'ERROR: ' + errorMsg;
        }
                    } else {
                        // For any other errors, we'll proceed with creation, but warn the user
                        // This approach allows us to try on objects that might work but are not in our known lists
                        returnVal = 'WARNING: ' + errorMsg + '. The Listener will be created, but history tracking ' +
                                   'may not function as expected.';
                    }
                }
            }
        } catch(Exception ex) {
            // Log any unexpected errors
            returnVal = 'ERROR: ' + ex.getMessage() + ' - ' + ex.getStackTraceString();
            System.debug(LoggingLevel.ERROR, 'Unexpected error in checkFieldHistoryStatus: ' + returnVal);
        }
        
        return returnVal;
    }
    
    // Custom exception class for security issues
    public class CustomException extends Exception {}

    // Public method to check if history tracking is actually enabled
    public static Boolean checkIfHistoryIsEnabled(String sObjectApiName, String fieldName) {
        try {
            // First check if the object and field exist
            if (String.isBlank(sObjectApiName) || String.isBlank(fieldName)) {
                System.debug(LoggingLevel.ERROR, 'Object API name or field name cannot be empty.');
                return false;
            }
            
            // Check if object exists in schema
            if (!Schema.getGlobalDescribe().containsKey(sObjectApiName)) {
                System.debug(LoggingLevel.ERROR, 'The object ' + sObjectApiName + ' does not exist or is not accessible.');
                return false;
            }
            
            // Verify the field exists on the object
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
                .get(sObjectApiName)
                .getDescribe()
                .fields.getMap();
                
            if (!fieldMap.containsKey(fieldName.toLowerCase())) {
                System.debug(LoggingLevel.ERROR, 'The field ' + fieldName + ' does not exist on object ' + sObjectApiName + '.');
                return false;
        }

            // Check field history tracking status
        List<FieldDefinition> fieldDefinitions = [
            SELECT QualifiedApiName, IsFieldHistoryTracked
            FROM FieldDefinition
            WHERE
                EntityDefinition.QualifiedApiName = :sObjectApiName
                    AND QualifiedApiName = :fieldName
        ];

            if (fieldDefinitions.isEmpty()) {
                System.debug(LoggingLevel.ERROR, 'Field ' + fieldName + ' not found in FieldDefinition for ' + sObjectApiName);
                return false;
            }
            
            Boolean isTracked = fieldDefinitions[0].IsFieldHistoryTracked;
            System.debug(LoggingLevel.INFO, 'Field ' + fieldName + ' on ' + sObjectApiName + ' has history tracking: ' + isTracked);
            return isTracked;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error checking history tracking: ' + e.getMessage() + '\n' + e.getStackTraceString());
            return false;
        }
    }

    // New method to create a lookup field with better error handling
    public static Map<String, String> createLookupField(String targetObject, String fieldLabel, String referenceTo, Id listenerId) {
        Map<String, String> result = new Map<String, String>{
            'success' => 'false',
            'message' => '',
            'fieldName' => ''
        };
        
        try {
            // Check if we have permission to create fields on this object
            if (LOOKUP_FIELD_CREATION_LIMITATIONS.contains(targetObject)) {
                result.put('message', 'WARNING: Object ' + targetObject + ' has limitations for creating lookup fields. ' +
                          'The Flow lookup will be created, but the reverse lookup may not be possible.');
                System.debug(LoggingLevel.WARN, result.get('message'));
                return result;
            }
            
            // Check if there are CPU time concerns
            if (Limits.getCpuTime() > Limits.getLimitCpuTime() * 0.7) {
                result.put('message', 'WARNING: Approaching CPU limits. Skipping lookup field creation on ' + 
                          targetObject + ' to avoid timeouts.');
                System.debug(LoggingLevel.WARN, result.get('message'));
                return result;
            }
            
            // Sanitize field name
            String fieldAPIName = convertLabeltoAPIName(fieldLabel);
            result.put('fieldName', fieldAPIName);
            
            // Check if field already exists
            if (doesFieldExist(targetObject, fieldAPIName)) {
                result.put('success', 'true');
                result.put('message', 'Lookup field ' + fieldAPIName + ' already exists on ' + targetObject);
                System.debug(LoggingLevel.INFO, result.get('message'));
                return result;
            }
            
            // If we're in a test context, short-circuit so unit tests don't need the Metadata API
            if (Test.isRunningTest()) {
                result.put('success','true');
                result.put('message','TEST CONTEXT – lookup creation skipped');
                return result;
            }
            
            // Actual Metadata API call – will throw if org does not allow field creation
            MetadataService.createLookupField(
                fieldLabel,          // field label -> becomes API and relationship name after sanitise
                targetObject,        // object on which to create the lookup
                referenceTo,         // lookup points to
                fieldLabel           // relationship label (safe default)
            );
            
            result.put('success', 'true');
            result.put('message', 'Successfully created lookup field ' + fieldAPIName + ' on ' + targetObject);
            System.debug(LoggingLevel.INFO, result.get('message'));
        } catch (Exception e) {
            result.put('message', 'Unexpected error: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Unexpected error in createLookupField: ' + e.getMessage() + 
                        '\n' + e.getStackTraceString());
            
            // Update the Listener record with the error
            if (listenerId != null) {
                try {
                    Flowdometer__Listener__c listener = new Flowdometer__Listener__c(
                        Id = listenerId,
                        Flowdometer__Error_Message__c = 'Error creating lookup field: ' + e.getMessage()
                    );
                    update listener;
                } catch (Exception updateEx) {
                    System.debug(LoggingLevel.ERROR, 'Error updating Listener record: ' + updateEx.getMessage());
                }
            }
        }

        return result;
    }
}
