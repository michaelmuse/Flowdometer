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
    public static final Set<String> KNOWN_STANDARD_OBJECTS = new Set<String>{
        'Account',
        'ApiAnomalyEventStore',
        'Asset',
        'AssociatedLocation',
        'AuthorizationForm',
        'AuthorizationFormConsent',
        'AuthorizationFormDataUse',
        'AuthorizationFormText',
        'BackgroundOperation',
        'BusinessBrand',
        'BusinessHours',
        'CalendarModel',
        'Campaign',
        'Case',
        'CommSubscription',
        'CommSubscriptionChannelType',
        'CommSubscriptionConsent',
        'CommSubscriptionTiming',
        'Community',
        'ConsumptionRate',
        'ConsumptionSchedule',
        'Contact',
        'ContactPointAddress',
        'ContactPointConsent',
        'ContactPointEmail',
        'ContactPointPhone',
        'ContactPointTypeConsent',
        'ContentFolder',
        'Contract',
        'ContractLineItem',
        'Conversation',
        'CredentialStuffingEventStore',
        'CreditMemo',
        'CreditMemoInvApplication',
        'CreditMemoLine',
        'Customer',
        'DandBCompany',
        'DataUseLegalBasis',
        'DataUsePurpose',
        'EngagementChannelType',
        'Entitlement',
        'Idea',
        'Individual',
        'Lead',
        'LegalEntity',
        'Location',
        'LocationGroup',
        'Macro',
        'MessagingEndUser',
        'MessagingSession',
        'Opportunity',
        'OpportunityLineItem',
        'Order',
        'OrderItem',
        'OrgMetric',
        'OrgMetricScanSummary',
        'PartyConsent',
        'Payment',
        'PaymentAuthAdjustment',
        'PaymentAuthorization',
        'PaymentGroup',
        'Pricebook2',
        'ProcessException',
        'Product2',
        'ProductConsumptionSchedule',
        'QuickText',
        'Recommendation',
        'Refund',
        'ReportAnomalyEventStore',
        'Seller',
        'ServiceContract',
        'SessionHijackingEventStore',
        'SocialPersona',
        'Solution',
        'ThreatDetectionFeedback',
        'User',
        'UserProvAccount',
        'UserProvisioningLog',
        'UserProvisioningRequest',
        'WaveAnnotationTarget',
        'WebCartDocument'
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
        while (System.currentTimeMillis() - startTime < milliseconds) {
            // Simulate wait by using some CPU time
            // Keep this minimal to avoid hitting CPU limits
            if (Math.mod(System.currentTimeMillis() - startTime, 500) == 0) {
                // Check every 500ms to reduce CPU usage
                System.debug(LoggingLevel.FINEST, 'Waiting...');
            }
        }
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
            
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
                .get(objName)
                ?.getDescribe()
                .fields.getMap();
            
            if (fieldMap == null) {
                System.debug(
                    LoggingLevel.INFO,
                    objName + ' is not a valid Salesforce Object or is not accessible.'
                );
                return false;
            }

            // Safe string operations for managed package objects
            if (fieldName != null && fieldName.toLowerCase().startsWith('flowdometer__') && 
                objName != null && !objName.toLowerCase().startsWith('flowdometer__')) {
                // Safely extract substring only if the prefix exists
                fieldName = fieldName.substring(Math.min(fieldName.length(), 'flowdometer__'.length()));
            }
            
            // Handle managed package fields in managed package objects
            if (objName != null && objName.contains('__')) {
                List<String> parts = objName.split('__');
                if (parts.size() > 2 && !objName.startsWith('Flowdometer__')) {
                    // This is likely a managed package object with a namespace
                    System.debug(
                        LoggingLevel.INFO,
                        objName + ' appears to be a managed package object. Assuming field ' + fieldName + ' does not exist for safety.'
                    );
                    return false;
                }
            }

            return fieldMap.containsKey(fieldName.toLowerCase());
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
        try {
            // Early check for null/empty inputs
            if (String.isBlank(sObjectApiName) || String.isBlank(fieldName)) {
                return 'ERROR: Object API name or field name cannot be empty.';
            }
            
            // Special object type checks - identify problematic objects early
            Set<String> specialObjectTypes = new Set<String>{
                'User', 'Group', 'GroupMember', 'Profile', 'PermissionSet', 
                'LoginHistory', 'NetworkMember', 'CollaborationGroup',
                'ContentDocument', 'ContentVersion', 'ContentWorkspace'
            };
            
            // External objects have __x suffix
            Boolean isExternalObject = sObjectApiName.endsWith('__x');
            // Big objects have __b suffix
            Boolean isBigObject = sObjectApiName.endsWith('__b');
            // Platform events have __e suffix
            Boolean isPlatformEvent = sObjectApiName.endsWith('__e');
            
            if (isExternalObject) {
                return 'WARNING: External objects (' + sObjectApiName + ') do not support history tracking. The Listener will be created, but some functionality may be limited.';
            }
            
            if (isBigObject) {
                return 'WARNING: Big objects (' + sObjectApiName + ') do not support history tracking. The Listener will be created, but some functionality may be limited.';
            }
            
            if (isPlatformEvent) {
                return 'WARNING: Platform events (' + sObjectApiName + ') do not support history tracking. The Listener will be created, but some functionality may be limited.';
            }
            
            if (specialObjectTypes.contains(sObjectApiName)) {
                return 'WARNING: The object ' + sObjectApiName + ' has special behavior in Salesforce. The Listener will be created, but some functionality may be limited.';
            }
            
            // Check early if this is a managed package object (other than our own)
            if (sObjectApiName.contains('__') && 
                sObjectApiName.split('__').size() > 2 && 
                !sObjectApiName.startsWith('Flowdometer__')) {
                System.debug(LoggingLevel.INFO, 
                            'Object ' + sObjectApiName + ' appears to be from a managed package. ' +
                            'Some operations may not be permitted.');
                // Since this is from a managed package, we'll treat it as if history is already enabled
                // This ensures we don't attempt operations that might fail
                return 'WARNING: ' + sObjectApiName + ' is from a managed package. History tracking and lookup creation might be limited by the package settings. The Listener will be created, but full functionality cannot be guaranteed.';
            }
            
            // Verify the object actually exists in the schema
            if (!Schema.getGlobalDescribe().containsKey(sObjectApiName)) {
                return 'ERROR: The object ' + sObjectApiName + ' does not exist or is not accessible.';
            }
            
            // Verify the field exists on the object
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
                .get(sObjectApiName)
                .getDescribe()
                .fields.getMap();
                
            if (!fieldMap.containsKey(fieldName.toLowerCase())) {
                return 'ERROR: The field ' + fieldName + ' does not exist on object ' + sObjectApiName + '.';
            }
            
            // Check if the object type supports history tracking
            // Some standard objects don't support history tracking
            Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe()
                .get(sObjectApiName)
                .getDescribe();
                
            // Hard-coded list of objects known not to support history tracking
            Set<String> noHistoryObjects = new Set<String>{
                'ContentDocument', 'ContentDocumentLink', 'ContentVersion', 
                'Attachment', 'Note', 'EmailMessage', 'FeedItem', 'ListView'
            };
            
            if (noHistoryObjects.contains(sObjectApiName)) {
                return 'WARNING: The object ' + sObjectApiName + ' does not support history tracking. The Listener will be created, but functionality will be limited.';
            }
            
            // General Setup from here on is the same as before
            Boolean historyEnabledForObject = false;
            String flowObjectAPIName = 'Flowdometer__Flow__c';

            // Check if the lookup from the Flow to sObject exists
            setLookupFieldMaps(flowObjectAPIName);
            flowAlreadyHasLookupTosObject = relatedLookupMap.containsKey(
                sObjectApiName
            );

            // Check if the lookup from the sObject to Flow exists
            setLookupFieldMaps(sObjectApiName);
            sObjectAlreadyHasLookupToFlow = relatedLookupMap.containsKey(
                flowObjectAPIName
            );

            Boolean objectCanBeLookedUpTo = (KNOWN_STANDARD_OBJECTS.contains(
                sObjectApiName
            ) || sObjectApiName.contains('__c'));

            // Make sure the sObject gets history tracking enabled if it is a standard object or a custom object
            if (objectCanBeLookedUpTo) {
                if (!Test.isRunningTest()) {
                    try {
                        historyEnabledForObject = MetadataService.validateHistoryEnabled(
                            sObjectApiName
                        );
                    } catch (Exception e) {
                        System.debug(LoggingLevel.ERROR, 'Error validating history tracking: ' + e.getMessage());
                        return 'WARNING: Could not verify history tracking for ' + sObjectApiName + '. The Listener will be created, but you may need to enable history tracking manually.';
                    }
                }
            } else {
                historyEnabledForObject = true;
            }
            
            // Cleaning fieldLabel
            String fieldLabel = sObjectApiName.contains('__c')
                ? sObjectApiName.replace('__c', '')
                : sObjectApiName;
            String namespacePrefix = 'Flowdometer__';
            if (sObjectApiName.startsWith(namespacePrefix)) {
                fieldLabel = fieldLabel.replace(namespacePrefix, '');
            }

            // Setting field labels
            String lookupFieldLabel =
                Schema.getGlobalDescribe()
                    .get(sObjectApiName)
                    .getDescribe()
                    .fields.getMap()
                    .get(fieldName)
                    .getDescribe()
                    .getLabel() + ' Flow';
            String sObjectLabel = Schema.getGlobalDescribe()
                .get(sObjectApiName)
                .getDescribe()
                .getLabel();

            // Sanitizing the field labels
            String apiConvertedLabelForLookupToFlow = convertLabeltoAPIName(
                lookupFieldLabel
            );
            String apiConvertedLabelForLookupTosObject = convertLabeltoAPIName(
                sObjectLabel
            );

            // Conditionally create the lookup from Flow to sObject
            if (!flowAlreadyHasLookupTosObject) {
                // Check if lookup to the sObject on Flowdometer__Flow__c already exists
                Boolean isLookupToSObjectAvailable = (doesFieldExist(
                    flowObjectAPIName,
                    apiConvertedLabelForLookupTosObject
                ) && objectCanBeLookedUpTo); //Check if lookup is possible, and does field exist: object to check, fieldLookingUpToOtherObject to check for

                // Create lookup on Flowdometer__Flow__c if it doesn't exist
                if (!isLookupToSObjectAvailable) {
                    if (!Test.isRunningTest()) {
                        try {
                            MetadataService.createLookupField(
                                sObjectLabel,
                                flowObjectAPIName,
                                sObjectApiName,
                                FLOWDOMETER_FLOW_OBJECT_LABEL
                            ); //FieldLabelForLookupField, objectAPINameToPutLookupOn, relatedObjectPointedTo, relationshipLabelNameChildren
                            grantFieldEditAccess(
                                flowObjectAPIName,
                                apiConvertedLabelForLookupTosObject
                            ); // objectAPINameWLookup, LookupFieldAPIName
                        } catch (Exception e) {
                            System.debug(LoggingLevel.ERROR, 'Error creating lookup to sObject: ' + e.getMessage());
                            return 'WARNING: Could not create lookup field from Flow to ' + sObjectApiName + '. This might limit functionality.';
                        }
                    }
                }

                flowAlreadyHasLookupTosObject = true;
            }

            // Conditionally create the lookup from sObject to Flow
            if (!sObjectAlreadyHasLookupToFlow) {
                // Check if lookup to Flowdometer__Flow__c on the sObject already exists
                Boolean isLookupToFlowAvailable = doesFieldExist(
                    sObjectApiName,
                    apiConvertedLabelForLookupToFlow
                ); //object to check, fieldLookingUpToOtherObject to check for

                // Create lookup on sObject if it doesn't exist
                if (!isLookupToFlowAvailable) {
                    if (!Test.isRunningTest()) {
                        try {
                            MetadataService.createLookupField(
                                lookupFieldLabel,
                                sObjectApiName,
                                flowObjectAPIName,
                                sObjectLabel
                            ); //FieldLabelForLookupField, objectAPINameToPutLookupOn, relatedObjectPointedTo, relationshipLabelNameChildren
                            grantFieldEditAccess(
                                sObjectApiName,
                                apiConvertedLabelForLookupToFlow
                            ); //permission set, objectAPINameWLookup, LookupFieldAPIName
                        } catch (Exception e) {
                            System.debug(LoggingLevel.ERROR, 'Error creating lookup from sObject to Flow: ' + e.getMessage());
                            return 'WARNING: Could not create lookup field from ' + sObjectApiName + ' to Flow. This might limit functionality.';
                        }
                    }
                }

                sObjectAlreadyHasLookupToFlow = true;
            }
            
            // Set up history tracking for the sObject field referenced
            String fieldAPIName = fieldName;
            List<FieldDefinition> fieldDefinitions = [
                SELECT QualifiedApiName, IsFieldHistoryTracked
                FROM FieldDefinition
                WHERE
                    EntityDefinition.QualifiedApiName = :sObjectApiName
                    AND IsFieldHistoryTracked = TRUE
            ];

            Map<String, FieldDefinition> trackedFieldsByName = new Map<String, FieldDefinition>();
            for (FieldDefinition field : fieldDefinitions) {
                if (field.IsFieldHistoryTracked) {
                    trackedFieldsByName.put(field.QualifiedApiName, field);
                }
            }

            // Get all the fields that have history tracking enabled
            // Check if we are out of available field history tracking
            if (
                trackedFieldsByName.size() == 20 &&
                !trackedFieldsByName.containsKey(fieldAPIName) &&
                historyEnabledForObject
            ) {
                return HISTORY_ENABLED_HAS_NO_LIMITS;
            } else if (
                !trackedFieldsByName.isEmpty() &&
                trackedFieldsByName.containsKey(fieldAPIName) &&
                historyEnabledForObject
            ) {
                return HISTORY_ENABLED_ALREADY;
            } else if (
                trackedFieldsByName.size() < 20 &&
                historyEnabledForObject &&
                !trackedFieldsByName.containsKey(fieldAPIName)
            ) {
                if (!Test.isRunningTest()) {
                    try {
                        MetadataService.enableFieldHistoryTracking(
                            sObjectApiName,
                            fieldAPIName
                        );
                    } catch (Exception e) {
                        System.debug(LoggingLevel.ERROR, 'Error enabling field history tracking: ' + e.getMessage());
                        return 'WARNING: Could not enable history tracking for ' + fieldAPIName + ' on ' + sObjectApiName + '. The Listener will be created, but functionality will be limited.';
                    }
                }

                return HISTORY_ENABLED_HAS_LIMITS;
            } else if (!historyEnabledForObject) {
                if (!Test.isRunningTest()) {
                    try {
                        MetadataService.enableFieldHistoryTracking(
                            sObjectApiName,
                            fieldAPIName
                        );
                    } catch (Exception e) {
                        System.debug(LoggingLevel.ERROR, 'Error enabling field history tracking: ' + e.getMessage());
                        return 'WARNING: Could not enable history tracking for the object ' + sObjectApiName + '. The Listener will be created, but functionality will be limited.';
                    }
                }

                return HISTORY_NOT_ENABLED_EARLIER_BUT_ENABLED_NOW;
            }

            return null;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Unexpected error in checkFieldHistoryStatus: ' + e.getMessage() + '\n' + e.getStackTraceString());
            // Return a error message to allow processing to continue
            return 'ERROR: ' + e.getMessage();
        }
    }
}
