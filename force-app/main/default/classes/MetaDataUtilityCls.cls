/**
 * Utility for runtime metadata operations (lookup field creation, history
 * tracking, dynamic FLS grants).
 *
 * Sharing: `inherited sharing` is the Salesforce-recommended pattern for a
 * utility called from multiple contexts (LWC `with sharing` controllers,
 * Queueables, the setup reconciler). It runs in the caller's sharing context
 * rather than silently elevating. Sharing keywords govern row-level record
 * sharing only - they do NOT control FLS. The FieldPermissions DML below is a
 * setup-object operation gated by the running user's "Manage Profiles and
 * Permission Sets" permission, independent of this declaration.
 */
public inherited sharing class MetaDataUtilityCls {
    public static final String HISTORY_ENABLED_HAS_NO_LIMITS = 'HISTORY_ENABLED_HAS_NO_LIMITS';
    public static final String HISTORY_NOT_ENABLED_EARLIER_BUT_ENABLED_NOW = 'HISTORY_NOT_ENABLED_EARLIER_BUT_ENABLED_NOW';
    public static final String HISTORY_ENABLED_ALREADY = 'HISTORY_ENABLED_ALREADY';
    public static final String HISTORY_ENABLED_HAS_LIMITS = 'HISTORY_ENABLED_HAS_LIMITS';
    // Dynamic FLS lands on the UNMANAGED permission set, never the managed one.
    // A managed (packaged) permission set rejects FieldPermissions DML in a
    // subscriber org (CANNOT_MODIFY_MANAGED_OBJECT). The unmanaged PS is
    // created/reconciled by FlowdometerPermissionReconciler (Build Plan A.0).
    @TestVisible private static String dynamicFlsPermissionSetName = 'Flowdometer_Dynamic_FLS';
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

    /**
     * Grant read/edit FLS for a runtime-created lookup field on the UNMANAGED
     * Flowdometer_Dynamic_FLS permission set via native FieldPermissions DML
     * (no Metadata API callout). FieldPermissions is a setup object: it is
     * governed by the running user's "Manage Profiles and Permission Sets"
     * permission, not by record sharing - so the `inherited sharing` on this
     * class does not affect the operation. Called for a single field per
     * invocation (e.g. from the chained FLSGrantJob), never inside a loop.
     */
    public static Boolean grantFieldAccessWithDml(
        String objectApiName,
        String fieldApiName
    ) {
        if (String.isBlank(objectApiName) || String.isBlank(fieldApiName)) {
            System.debug(LoggingLevel.WARN, 'Cannot grant FLS with blank object or field API name.');
            return false;
        }

        // The object API name is already correct as supplied by the caller:
        // standard objects as-is (Opportunity, Contract), the managed Flow__c
        // object resolved via describe to its namespaced name
        // (Flowdometer__Flow__c), and subscriber custom objects without any
        // namespace (e.g. QA_Tracked__c). Do NOT namespace-qualify the OBJECT -
        // doing so breaks FLS for subscriber custom objects (QA_Tracked__c would
        // become Flowdometer__QA_Tracked__c, which does not exist). Only the
        // FIELD portion may need the package namespace (for packaged fields).
        String qualifiedObjectApiName = objectApiName;

        // Build two candidate Field values: one for dynamic fields (no namespace
        // on the field portion) and one for packaged fields (namespace-qualified).
        // Dynamic fields created at runtime via the Tooling API never carry the
        // namespace prefix. Packaged fields that ship with the package do.
        // We query for both and let the org tell us which is real.
        String fieldFullName = qualifiedObjectApiName + '.' + fieldApiName;
        String qualifiedFieldApiName = qualifyCustomApiNameForSetup(fieldApiName);
        String qualifiedFieldFullName = qualifiedObjectApiName + '.' + qualifiedFieldApiName;

        List<String> candidateFieldNames = new List<String>{ fieldFullName };
        if (qualifiedFieldFullName != fieldFullName) {
            candidateFieldNames.add(qualifiedFieldFullName);
        }

        System.debug(LoggingLevel.INFO,
            'grantFieldAccessWithDml: objectApiName=' + objectApiName +
            ', fieldApiName=' + fieldApiName +
            ', qualifiedObject=' + qualifiedObjectApiName +
            ', candidates=' + candidateFieldNames +
            ', namespace=' + resolveNamespace());

        try {
            // Resolve by name only: the runtime-created unmanaged PS carries the
            // org namespace in a namespaced build org but null in a subscriber,
            // and no packaged PS uses this name.
            List<PermissionSet> permissionSets = [
                SELECT Id
                FROM PermissionSet
                WHERE Name = :dynamicFlsPermissionSetName
                LIMIT 1
            ];

            if (permissionSets.isEmpty()) {
                System.debug(LoggingLevel.WARN,
                    'Flowdometer dynamic FLS permission set not found: ' + dynamicFlsPermissionSetName +
                    '. The setup gate (FlowdometerPermissionReconciler) creates it on entry.');
                return false;
            }

            Id permissionSetId = permissionSets[0].Id;

            List<FieldPermissions> existingPermissions = [
                SELECT Id, PermissionsRead, PermissionsEdit, Field
                FROM FieldPermissions
                WHERE ParentId = :permissionSetId
                  AND SobjectType = :qualifiedObjectApiName
                  AND Field IN :candidateFieldNames
                LIMIT 1
            ];

            if (!existingPermissions.isEmpty()) {
                FieldPermissions existingPermission = existingPermissions[0];
                System.debug(LoggingLevel.INFO,
                    'grantFieldAccessWithDml: found existing permission for ' +
                    existingPermission.Field);

                if (existingPermission.PermissionsRead && existingPermission.PermissionsEdit) {
                    return true;
                }

                existingPermission.PermissionsRead = true;
                existingPermission.PermissionsEdit = true;
                update existingPermission;
                return true;
            }

            // No existing permission — insert a new one. Try the unqualified
            // (dynamic-field) name first since that's the primary runtime path.
            // Fall back to the namespace-qualified name for packaged fields.
            String insertFieldName = fieldFullName;
            try {
                insert new FieldPermissions(
                    ParentId = permissionSetId,
                    SobjectType = qualifiedObjectApiName,
                    Field = insertFieldName,
                    PermissionsRead = true,
                    PermissionsEdit = true
                );
                System.debug(LoggingLevel.INFO,
                    'grantFieldAccessWithDml: inserted FLS for ' + insertFieldName);
                return true;
            } catch (DmlException dmlEx) {
                if (qualifiedFieldFullName != fieldFullName) {
                    System.debug(LoggingLevel.INFO,
                        'grantFieldAccessWithDml: insert with ' + insertFieldName +
                        ' failed, retrying with ' + qualifiedFieldFullName);
                    insert new FieldPermissions(
                        ParentId = permissionSetId,
                        SobjectType = qualifiedObjectApiName,
                        Field = qualifiedFieldFullName,
                        PermissionsRead = true,
                        PermissionsEdit = true
                    );
                    System.debug(LoggingLevel.INFO,
                        'grantFieldAccessWithDml: inserted FLS for ' + qualifiedFieldFullName);
                    return true;
                }
                throw dmlEx;
            }
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                'Error granting field access with DML for ' + fieldFullName +
                ' (also tried ' + qualifiedFieldFullName + '): ' +
                e.getMessage() + '\n' + e.getStackTraceString()
            );
            return false;
        }
    }

    private static String resolveNamespace() {
        String className = MetaDataUtilityCls.class.getName();
        return className.contains('.') ? className.substringBefore('.') : '';
    }

    private static Boolean isNamespaceQualified(String apiName) {
        return String.isNotBlank(apiName) &&
            apiName.endsWith('__c') &&
            apiName.split('__').size() >= 3;
    }

    private static String qualifyCustomApiNameForSetup(String apiName) {
        String namespacePrefix = resolveNamespace();
        if (String.isBlank(namespacePrefix) ||
            String.isBlank(apiName) ||
            !apiName.endsWith('__c') ||
            isNamespaceQualified(apiName)) {
            return apiName;
        }

        return namespacePrefix + '__' + apiName;
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

            // In managed packages, fields created via Metadata API automatically get the namespace prefix (e.g., Flowdometer__Name_Flow__c)
            // The fieldMap contains field names exactly as they exist in the schema, including namespace prefixes
            // Perform a case-insensitive comparison so we don't miss matches that differ only by letter-case.
            // Two candidates: the name as supplied AND the namespace-qualified
            // form. Packaged fields carry the namespace in installed orgs
            // (Flowdometer__Opportunity__c), so checking only the unqualified
            // name missed them and the product created unmanaged DUPLICATES of
            // its own shipped lookups on Flow__c (confirmed 2026-06-10). The
            // qualified candidate is harmless for subscriber objects - no
            // subscriber field can carry this package's namespace.
            String needle = fieldName.toLowerCase();
            String qualifiedNeedle = qualifyCustomApiNameForSetup(fieldName).toLowerCase();
            for(String existingName : fieldMap.keySet()) {
                if(existingName != null &&
                   (existingName.toLowerCase() == needle ||
                    existingName.toLowerCase() == qualifiedNeedle)) {
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

    /**
     * Build an org-unique child relationship name for a dynamically created
     * lookup: "<objectBase>_<fieldBase>", sanitized to Salesforce developer
     * name rules (no consecutive/leading/trailing underscores, max 40 chars).
     * Examples: (Case, Status_Flow__c) -> Case_Status_Flow;
     * (QA_Tracked__c, Status_Flow__c) -> QA_Tracked_Status_Flow.
     */
    @TestVisible
    private static String buildRelationshipName(String targetObject, String fieldApiName) {
        String objectBase = stripApiSuffix(targetObject);
        String fieldBase = stripApiSuffix(fieldApiName);
        String combined = (objectBase + '_' + fieldBase)
            .replaceAll('_+', '_')
            .removeStart('_')
            .removeEnd('_');
        if (combined.length() > 40) {
            combined = combined.substring(0, 40).removeEnd('_');
        }
        return combined;
    }

    private static String stripApiSuffix(String apiName) {
        if (String.isBlank(apiName)) {
            return '';
        }
        String base = apiName;
        if (base.endsWithIgnoreCase('__c')) {
            base = base.substring(0, base.length() - 3);
        }
        return base;
    }

    // Sanitize the field name to adhere to Salesforce's naming conventions
    public static String convertLabeltoAPIName(String originalName) {
        String sanitized = originalName.replaceAll('[^a-zA-Z0-9]', '_'); // Replace non-alphanumeric characters with underscores
        sanitized = '' + sanitized + '__c';
        System.debug(LoggingLevel.INFO, sanitized);
        return sanitized;
    }

    private static final String TOOLING_API_VERSION = 'v65.0';

    /**
     * Enable field history tracking for standard objects using Tooling API REST calls.
     * FieldDefinition.IsFieldHistoryTracked is read-only via DML, so we use REST API.
     */
    private static Boolean enableFieldHistoryTrackingViaTooling(String sObjectApiName, String fieldName) {
        try {
            List<FieldDefinition> fieldDefs = [
                SELECT Id, QualifiedApiName, IsFieldHistoryTracked
                FROM FieldDefinition
                WHERE EntityDefinition.QualifiedApiName = :sObjectApiName
                AND QualifiedApiName = :fieldName
                LIMIT 1
            ];

            if (fieldDefs.isEmpty()) {
                System.debug(LoggingLevel.ERROR, 'FieldDefinition not found for ' + sObjectApiName + '.' + fieldName);
                return false;
            }

            FieldDefinition fieldDef = fieldDefs[0];

            if (fieldDef.IsFieldHistoryTracked) {
                System.debug(LoggingLevel.INFO, 'History tracking already enabled for ' + sObjectApiName + '.' + fieldName);
                return true;
            }

            FlowdometerTokenService.TokenResult tokenResult = FlowdometerTokenService.getToken();
            if (!tokenResult.success) {
                System.debug(LoggingLevel.ERROR, 'Cannot enable history tracking – token acquisition failed.');
                return false;
            }

            String toolingBase = URL.getOrgDomainUrl().toExternalForm()
                + '/services/data/' + TOOLING_API_VERSION + '/tooling';

            Map<String, Object> updatePayload = new Map<String, Object>();
            updatePayload.put('IsFieldHistoryTracked', true);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(toolingBase + '/sobjects/FieldDefinition/' + fieldDef.Id);
            req.setMethod('PATCH');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + tokenResult.accessToken);
            req.setBody(JSON.serialize(updatePayload));
            req.setTimeout(120000);

            HttpResponse resp = new Http().send(req);

            System.debug(LoggingLevel.INFO, 'Tooling API REST response for ' + sObjectApiName + '.' + fieldName +
                        ': Status=' + resp.getStatusCode());

            if (resp.getStatusCode() >= 200 && resp.getStatusCode() < 300) {
                List<FieldDefinition> verifyDefs = [
                    SELECT Id, QualifiedApiName, IsFieldHistoryTracked
                    FROM FieldDefinition
                    WHERE Id = :fieldDef.Id
                    LIMIT 1
                ];

                if (!verifyDefs.isEmpty() && verifyDefs[0].IsFieldHistoryTracked) {
                    return true;
                } else {
                    System.debug(LoggingLevel.WARN, 'Tooling API call succeeded but field is still not tracked. Field may not be eligible for history tracking.');
                    return false;
                }
            } else {
                System.debug(LoggingLevel.ERROR, 'Could not enable history tracking via Tooling API REST. Status: ' + resp.getStatusCode());
                return false;
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error enabling history tracking via Tooling API: ' + e.getMessage());
            return false;
        }
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
            
            // Special handling for Case and Opportunity - check if history tracking is supported
            // but we still need to verify the specific field is tracked
            if(sObjectApiName == 'Opportunity' || sObjectApiName == 'Case') {
                String historyName = sObjectApiName == 'Opportunity' ? 'OpportunityFieldHistory' : 'CaseHistory';
                
                try {
                    // Verify if the history object exists and is accessible
                    SObjectType historyType = Schema.getGlobalDescribe().get(historyName);
                    if(historyType != null && historyType.getDescribe().isAccessible()) {
                        System.debug(LoggingLevel.INFO, 'History tracking is supported for ' + sObjectApiName + 
                                    ' through ' + historyName);
                        // Continue to check if the specific field is actually tracked
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
            
            // Check for history tracking on the specific field
            String tmpVar1 = sObjectApiName;
            List<Schema.FieldDefinition> fieldDefs = [
                SELECT QualifiedApiName, IsFieldHistoryTracked
                FROM FieldDefinition
                WHERE EntityDefinition.QualifiedApiName = :tmpVar1 
                AND QualifiedApiName = :fieldName
                LIMIT 1
            ];
            
            Boolean isHistoryTrackedForThisField = false;
            if (!fieldDefs.isEmpty()) {
                isHistoryTrackedForThisField = fieldDefs[0].IsFieldHistoryTracked;
                System.debug(LoggingLevel.INFO, 'Field ' + sObjectApiName + '.' + fieldName + 
                            ' has IsFieldHistoryTracked = ' + isHistoryTrackedForThisField);
            } else {
                System.debug(LoggingLevel.WARN, 'FieldDefinition not found for ' + sObjectApiName + '.' + fieldName);
            }
            
            // If field is already tracked for history, return success
            if(isHistoryTrackedForThisField) {
                returnVal = 'HISTORY_ENABLED_ALREADY';
                System.debug(LoggingLevel.INFO, 'History tracking already enabled for ' + 
                            sObjectApiName + '.' + fieldName);
            } else {
                try {
                    // Try to enable history tracking for the field using Metadata API
                    // This works for both custom and standard objects
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

            // Check if user has access to the FieldDefinition object
            Schema.DescribeSObjectResult describeResult = FieldDefinition.SObjectType.getDescribe();
            if (!describeResult.isAccessible()) {
                System.debug(LoggingLevel.ERROR, 'User does not have access to FieldDefinition object');
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

    /**
     * Create a lookup field using Tooling API REST (replaces SOAP MetadataService).
     */
    private static Boolean createLookupFieldViaTooling(String targetObject, String fieldLabel, String referenceTo) {
        try {
            FlowdometerTokenService.TokenResult tokenResult = FlowdometerTokenService.getToken();
            if (!tokenResult.success) {
                System.debug(LoggingLevel.ERROR, 'Cannot create lookup field – token acquisition failed.');
                return false;
            }

            String toolingBase = URL.getOrgDomainUrl().toExternalForm()
                + '/services/data/' + TOOLING_API_VERSION + '/tooling';

            String fieldApiName = convertLabeltoAPIName(fieldLabel);

            Map<String, Object> fieldMetadata = new Map<String, Object>{
                'FullName' => targetObject + '.' + fieldApiName,
                'Metadata' => new Map<String, Object>{
                    'label' => fieldLabel,
                    'type' => 'Lookup',
                    'referenceTo' => referenceTo,
                    'relationshipLabel' => fieldLabel,
                    // Child relationship names live on the REFERENCED object
                    // and must be unique there. All forward lookups reference
                    // Flow__c, so deriving the relationship name from the
                    // field name alone collides when two listeners track
                    // same-labeled fields on different objects (e.g.
                    // Case.Status_Flow__c + QA_Tracked__c.Status_Flow__c both
                    // -> "Status_Flow" on Flow__c -> DUPLICATE_DEVELOPER_NAME).
                    // Qualify with the target object to de-collide. The FIELD
                    // API name is unchanged, so reverse-population resolution
                    // and existing orgs are unaffected.
                    'relationshipName' => buildRelationshipName(targetObject, fieldApiName),
                    'deleteConstraint' => 'SetNull'
                }
            };

            HttpRequest req = new HttpRequest();
            req.setEndpoint(toolingBase + '/sobjects/CustomField');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + tokenResult.accessToken);
            req.setBody(JSON.serialize(fieldMetadata));
            req.setTimeout(120000);

            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() == 201) {
                System.debug(LoggingLevel.INFO, 'Successfully created lookup field: ' + fieldApiName);
                return true;
            } else {
                System.debug(LoggingLevel.ERROR, 'Failed to create lookup field. Status: ' +
                            res.getStatusCode() + ', Body: ' + res.getBody());
                return false;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Exception creating lookup field: ' + e.getMessage());
            return false;
        }
    }

    // New method to create a lookup field with better error handling
    public static Map<String, String> createLookupField(String targetObject, String fieldLabel, String referenceTo, Id listenerId) {
        Map<String, String> result = new Map<String, String>{
            'success' => 'false',
            'message' => '',
            'error' => '',
            'fieldName' => ''
        };
        
        // Declare fieldAPIName outside try block so it's available in catch block
        String fieldAPIName = convertLabeltoAPIName(fieldLabel);
        result.put('fieldName', fieldAPIName);
        
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
            
            // Check if field already exists
            if (doesFieldExist(targetObject, fieldAPIName)) {
                result.put('success', 'true');
                result.put('message', 'Lookup field ' + fieldAPIName + ' already exists on ' + targetObject);
                grantFieldAccessWithDml(targetObject, fieldAPIName);
                System.debug(LoggingLevel.INFO, result.get('message'));
                return result;
            }
            
            // Check for similar field names to avoid conflicts
            String similarFieldMessage = checkForSimilarFieldNames(targetObject, fieldAPIName);
            if (similarFieldMessage != null) {
                // If we find a similar field, treat it as a success case
                result.put('success', 'true');
                result.put('message', similarFieldMessage);
                System.debug(LoggingLevel.INFO, similarFieldMessage);
                return result;
            }
            
            // If we're in a test context, short-circuit so unit tests don't need the Metadata API
            if (Test.isRunningTest()) {
                result.put('success','true');
                result.put('message','TEST CONTEXT – lookup creation skipped');
                return result;
            }
            
            // Use REST Tooling API instead of SOAP MetadataService
            Boolean created = createLookupFieldViaTooling(targetObject, fieldLabel, referenceTo);
            
            if (created) {
                result.put('success', 'true');
                result.put('message', 'Successfully created lookup field ' + fieldAPIName + ' on ' + targetObject);
                result.put('error', '');
                Boolean grantedAccess = grantFieldAccessWithDml(targetObject, fieldAPIName);
                if (!grantedAccess) {
                    result.put(
                        'message',
                        result.get('message') + ', but Flowdometer could not grant FLS automatically.'
                    );
                }
                System.debug(LoggingLevel.INFO, result.get('message'));
            } else {
                result.put('message', 'Failed to create lookup field ' + fieldAPIName + ' on ' + targetObject);
                result.put('error', 'REST API call returned non-success status');
            }
        } catch (Exception e) {
            String errorMessage = e.getMessage();
            // Handle specific error cases
            if (errorMessage.contains('DUPLICATE_DEVELOPER_NAME')) {
                // If it's a duplicate field error, treat it as a success case
                result.put('success', 'true');
                result.put('message', 'Field ' + fieldAPIName + ' already exists on ' + targetObject);
                result.put('error', '');
                System.debug(LoggingLevel.INFO, result.get('message'));
                return result;
            }
            
            // For other errors, log them but don't update the Listener record
            System.debug(LoggingLevel.ERROR, 'Error in createLookupField: ' + errorMessage + 
                        '\n' + e.getStackTraceString());
            
            result.put('message', 'Error creating lookup field: ' + errorMessage);
            result.put('error', errorMessage);
        }

        return result;
    }
    
    // Helper method to check for similar field names
    private static String checkForSimilarFieldNames(String targetObject, String fieldAPIName) {
        try {
            // Get all fields for the object
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
                .get(targetObject)
                .getDescribe()
                .fields.getMap();
            
            // Check for exact match
            if (fieldMap.containsKey(fieldAPIName.toLowerCase())) {
                return 'A field named ' + fieldAPIName + ' already exists on ' + targetObject;
            }
            
            // Check for similar names (without __c suffix)
            String baseName = fieldAPIName.endsWith('__c') ? 
                fieldAPIName.substring(0, fieldAPIName.length() - 3) : 
                fieldAPIName;
                
            for (String existingField : fieldMap.keySet()) {
                String existingBaseName = existingField.endsWith('__c') ? 
                    existingField.substring(0, existingField.length() - 3) : 
                    existingField;
                    
                if (existingBaseName.equalsIgnoreCase(baseName)) {
                    return 'A field with a similar name (' + existingField + ') already exists on ' + targetObject;
                }
            }
            
            return null;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error checking for similar field names: ' + e.getMessage());
            return null;
        }
    }

}