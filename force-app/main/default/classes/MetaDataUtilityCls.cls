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

    //This method is used to grant field edit access via our permission set
    public static void grantFieldEditAccess(
        String objectApiName,
        String fieldApiName
    ) {
        //permission set, objectAPINameWLookup, LookupFieldAPIName
        try {
            MetadataService.MetadataPort service = MetadataService.createService();
            service.timeout_x = 120000; //Set timeout to maximum allowable callout time (2 min)
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
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'An error occurred: ' + e.getMessage());
        }
    }

    // Check before creating a new Lookup field
    public static Boolean doesFieldExist(String objName, String fieldName) {
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
            .get(objName)
            ?.getDescribe()
            .fields.getMap();
        if (fieldMap == null) {
            System.debug(
                LoggingLevel.INFO,
                objName + ' is not a valid Salesforce Object.'
            );
            return false;
        }

        return fieldMap.containsKey(fieldName.toLowerCase());
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
        // General Setup
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
                historyEnabledForObject = MetadataService.validateHistoryEnabled(
                    sObjectApiName
                );
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
                MetadataService.enableFieldHistoryTracking(
                    sObjectApiName,
                    fieldAPIName
                );
            }

            return HISTORY_ENABLED_HAS_LIMITS;
        } else if (!historyEnabledForObject) {
            if (!Test.isRunningTest()) {
                MetadataService.enableFieldHistoryTracking(
                    sObjectApiName,
                    fieldAPIName
                );
            }

            return HISTORY_NOT_ENABLED_EARLIER_BUT_ENABLED_NOW;
        }

        return null;
    }
}
