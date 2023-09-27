public with sharing class MetaDataUtilityCls {
    public static final String HISTORY_ENABLED_HAS_NO_LIMITS = 'HISTORY_ENABLED_HAS_NO_LIMITS';
    public static final String HISTORY_NOT_ENABLED_EARLIER_BUT_ENABLED_NOW = 'HISTORY_NOT_ENABLED_EARLIER_BUT_ENABLED_NOW';
    public static final String HISTORY_ENABLED_ALREADY = 'HISTORY_ENABLED_ALREADY';
    public static final String HISTORY_ENABLED_HAS_LIMITS = 'HISTORY_ENABLED_HAS_LIMITS';
    public static Map<String, String> fieldNameAPISetMap = new Map<String, String>();
    public static Map<String,String> relatedlookupMap = new Map<String,String>();
    public static Map<String,String> lookUpAPINameMap = new Map<String,String>();
    public static Boolean isRelationshipAvailable = FALSE;

    //This method is used to get the lookup field from the object
    @AuraEnabled(Cacheable=true)
    public static Map<String,String> getLookupField(String objectName){
        DescribeSObjectResult objDef = Schema.getGlobalDescribe().get(objectName).getDescribe();
        Map<String, SObjectField> fieldsObj = objDef.fields.getMap();
        Set<String> fieldSet = fieldsObj.keySet();
        DescribeFieldResult selectedField;
        for(String field : fieldSet){
            SObjectField fieldToken = fieldsObj.get(field);
            selectedField = fieldToken.getDescribe();
            if(selectedField.getType() == Schema.DisplayType.REFERENCE && selectedField.isCustom()){
                Schema.SObjectType relatedObjType = selectedField.getReferenceTo()[0];
                relatedlookupMap.put(relatedObjType.getDescribe().getName() ,relatedObjType.getDescribe().getLabel());
                lookUpAPINameMap.put(selectedField.getLabel(), selectedField.getName());
            }
        }
        return relatedlookupMap;
    }

    //This method is used to get the fields from the object
    @AuraEnabled(Cacheable=true)
    public static Map<String, String> getSObjectFields(String objectName){
        Map<String, String> sObjectFieldsMap = new Map<String, String>();
        Map<String, String> fieldSetMap = new Map<String, String>();
        SObjectType sobjType = Schema.getGlobalDescribe().get(objectName);
        Map<String, Schema.SObjectField> fieldsMap = sobjType.getDescribe().fields.getMap();
        for(Schema.SObjectField field : fieldsMap.values()){
            Schema.DescribeFieldResult fieldResult = field.getDescribe();
            Schema.DisplayType fieldType = fieldResult.getType();

            if(fieldResult.isAccessible()){
                sObjectFieldsMap.put(fieldResult.getName(),fieldResult.getLabel());
                fieldNameAPISetMap.put(fieldResult.getLabel(), fieldResult.getName());
            }
        }
        for(String key:getSortedKeySet(sObjectFieldsMap)){
            fieldSetMap.put(key, sObjectFieldsMap.get(key));
        }
        return fieldSetMap;
    }

    //This method is used to get all the objects from the org
    @AuraEnabled(Cacheable=true)
    public static Map<String, String> getAllSObjectsInOrg(){
        Map<String, String> objectAPIToLabelMap = new Map<String, String>();
        Map<String, String> objectAPINameMap = new Map<String, String>();
        Map<String, String> objectLabelAPINameMap = new Map<String, String>();
        Map<String, Schema.SObjectType> globalDescribeMap = Schema.getGlobalDescribe();

        for(String globalDescribeKey : globalDescribeMap.keySet()){
            Schema.SObjectType currentSObjectType = globalDescribeMap.get(globalDescribeKey);
            Schema.DescribeSObjectResult currentSObjectResult = currentSObjectType.getDescribe();
            String name = currentSObjectResult.getName();
            if(!name.containsignorecase('history') && !name.containsignorecase('tag')&&
                !name.containsignorecase('share') && !name.containsignorecase('feed') && !name.containsignorecase('changeevent')){      
                objectAPIToLabelMap.put(currentSObjectResult.getName(),currentSObjectResult.getLabel());
                objectLabelAPINameMap.put(currentSObjectResult.getLabel(),currentSObjectResult.getName());
            }
        }

        for(String key:getSortedKeySet(objectAPIToLabelMap)){
            objectAPINameMap.put(key, objectAPIToLabelMap.get(key));
        }
        return objectAPINameMap;
    }

    //This method is used to sort the keyset
    public static List<String> getSortedKeySet(Map<String, String> objectAPIToLabelMap){
        List<String> keySetLst = new List<String>();
        keySetLst.addAll(objectAPIToLabelMap.keySet());
        keySetLst.sort();
        return keySetLst;
    }
    
    
    //This method is used to grant field edit access via our permission set    
    public static void grantFieldEditAccess(String permissionSetName, String objectApiName, String fieldApiName) { //permission set, objectAPINameWLookup, LookupFieldAPIName
        try {
            MetadataService.MetadataPort service = MetadataService.createService();
            System.debug('service: ' + service);
            MetadataService.PermissionSet permissionSet = (MetadataService.PermissionSet) service.readMetadata(
                'PermissionSet', new String[] { permissionSetName }).getRecords()[0];
            System.debug('permissionSet: ' + permissionSet);
            MetadataService.PermissionSetFieldPermissions fieldPermission = new MetadataService.PermissionSetFieldPermissions();
            System.debug('fieldPermission: ' + fieldPermission);
            fieldPermission.field = objectApiName+'.'+fieldApiName;
            fieldPermission.editable = true;
            fieldPermission.readable = true;
            permissionSet.fieldPermissions.add(fieldPermission);
            System.debug('permissionSet.fieldPermissions: ' + permissionSet.fieldPermissions);
            List<MetadataService.SaveResult> results = service.updateMetadata(new MetadataService.Metadata[] { permissionSet });
						if (results != null && !results.isEmpty()) {
							MetadataService.handleSaveResults(results[0]);
						} else {
								System.debug('No results returned from metadata API.');
						}
        } catch (Exception e) {
            System.debug('An error occurred: ' + e.getMessage());
						System.debug(e.getStackTraceString());
        }
    }
    // Check before creating a new Lookup field
    public static Boolean doesFieldExist(String objName, String fieldName) { //object to check, field to check
			System.debug('objName: ' + objName);
			System.debug('fieldName: ' + fieldName);
			SObjectType sobjType = Schema.getGlobalDescribe().get(objName);
			if (sobjType == null) {
					return false; // Object doesn't exist
			}
			
			Map<String, Schema.SObjectField> fieldsMap = sobjType.getDescribe().fields.getMap();
			// Convert fieldName to lowercase for case-insensitive comparison
			String fieldNameLower = fieldName.toLowerCase();
			System.debug('Field API Name lowercase: ' + fieldNameLower);
			System.debug('fieldsMap: ' + fieldsMap);
			return fieldsMap.containsKey(fieldNameLower);
	}
    
    // Sanitize the field name to adhere to Salesforce's naming conventions
    public static String convertLabeltoAPIName(String originalName) {
        String sanitized = originalName.replaceAll('[^a-zA-Z0-9]', '_'); // Replace non-alphanumeric characters with underscores
        sanitized = 'Flowdometer__' + sanitized = '__c'
        return sanitized;
    }

    //This method checks if the selected field has history tracking enabled. If field history isn't enabled, then it shows the user a message to 'Enable the History tracking'.
    @AuraEnabled(Cacheable=true)  
    public static String checkFieldHistoryStatus(string sObjectAPIName, string fieldName){
        // General Setup
        Set<String> historyEnabledFields = new Set<String>();
        String fieldHistoryStatus = '';
        Set<String> stdObjects = new Set<String>{'Account', 'Contact', 'Lead','Opportunity','Case'};
        Boolean historyEnabledForObject = false;
        String fieldAPINameForLookupToFlow = '';
        String fieldAPINameForLookupToObject = '';

        // Check if the relationship between the sObject and Flowdometer__Flow__c exists
		String FlowObjectAPIName = 'Flowdometer__Flow__c';
        getLookupField('Flowdometer__Flow__c');
        isRelationshipAvailable = relatedlookupMap.containsKey(sObjectAPIName) ? TRUE : FALSE;
				System.debug('isRelationshipAvailable: ' + isRelationshipAvailable);
				System.debug('relatedlookupMap: ' + relatedlookupMap);
				System.debug('sObjectAPIName: ' + sObjectAPIName);
        if(stdObjects.contains(sObjectAPIName) || sObjectAPIName.contains('__c')){ //IS THIS RIGHT?
            if(!Test.isRunningTest()){
                historyEnabledForObject = MetadataService.validateHistoryEnabled(sObjectAPIName);
            }
        } else {
            historyEnabledForObject = true;
        }
        // Skip for Task object because it cant accept lookups
        if(sObjectAPIName != 'Task') {
            // Not sure what this does, seems to remove the '__c' from the end of the sObjectAPIName and set it to fieldLabel which isnt right
            String fieldLabel = sObjectAPIName.contains('__c') ? sObjectAPIName.replace('__c','') : sObjectAPIName;
            
            // Remove managed package namespace from fieldLabel
            String namespacePrefix = 'Flowdometer__';
            if(sObjectAPIName.startsWith(namespacePrefix)) {
                fieldLabel = fieldLabel.replace(namespacePrefix, '');
            }
            
            // Setting Object Labels
            DescribeSObjectResult sObjectDescribe = Schema.getGlobalDescribe().get(sObjectAPIName).getDescribe();
            String sObjectLabel = sObjectDescribe.getLabel();  // Label for the sObject should be human-readable
            String flowLabel = 'Flow';
            System.debug('sObjectLabel: ' + sObjectLabel);
            System.debug('flowLabel: ' + flowLabel);

            // Setting field labels
            DescribeFieldResult fieldDescribe = Schema.getGlobalDescribe().get(sObjectAPIName).getDescribe().fields.getMap().get(fieldName).getDescribe();
            String fieldLabelForLookupToFlow = fieldDescribe.getLabel() + ' Flow';
            String fieldLabelForLookupTosObject = sObjectLabel;
            System.debug('fieldLabelForLookupToFlow: ' + fieldLabelForLookupToFlow);
            System.debug('fieldLabelForLookupTosObject: ' + fieldLabelForLookupTosObject);

            // Setting fieldAPINames
            fieldAPINameForLookupToFlow = fieldName.replace('__c', '') + '_Flow__c';
            fieldAPINameForLookupToObject = sObjectAPIName;//.replace('__c', '');
            System.debug('fieldAPINameForLookupToFlow: ' + fieldAPINameForLookupToObject);
            System.debug('fieldAPINameForLookupToObject: ' + fieldAPINameForLookupToFlow);

            // Sanitizing the Labels
            String apiConvertedLabelForLookupToFlow = convertLabeltoAPIName(fieldLabelForLookupToFlow);
            String apiConvertedLabelForLookupTosObject = convertLabeltoAPIName(fieldLabelForLookupTosObject);
            System.debug('apiConvertedLabelForLookupToFlow: ' + apiConvertedLabelForLookupToFlow);
            System.debug('apiConvertedLabelForLookupTosObject: ' + apiConvertedLabelForLookupTosObject);

            // Check if lookup to the sObject on Flowdometer__Flow__c already exists
            Boolean isLookupToSObjectAvailable = doesFieldExist(FlowObjectAPIName, fieldAPINameForLookupToObject);  //object to check, fieldLookingUpToOtherObject to check for
            System.debug('isLookupToSObjectAvailable: ' + isLookupToSObjectAvailable);

            // Check if lookup to Flowdometer__Flow__c on the sObject already exists
            Boolean isLookupToFlowAvailable = doesFieldExist(sObjectAPIName, fieldAPINameForLookupToFlow);  //object to check, fieldLookingUpToOtherObject to check for
            System.debug('isLookupToFlowAvailable: ' + isLookupToFlowAvailable);

            // Create lookup on Flowdometer__Flow__c if it doesn't exist
            if (!isLookupToSObjectAvailable) {
                    if(!Test.isRunningTest()){
                            MetadataService.createLookupField(fieldLabelForLookupTosObject, FlowObjectAPIName, sObjectAPIName, flowLabel); //FieldLabelForLookupField, objectAPINameToPutLookupOn, relatedObjectPointedTo, relationshipLabelNameChildren
                            grantFieldEditAccess('Flowdometer_User', FlowObjectAPIName, fieldAPINameForLookupToObject); //permission set, objectAPINameWLookup, LookupFieldAPIName
                    }
            }

            // Create lookup on sObject if it doesn't exist
            if (!isLookupToFlowAvailable) {
                    if(!Test.isRunningTest()){
                            MetadataService.createLookupField(fieldLabelForLookupToFlow, sObjectAPIName, FlowObjectAPIName, sObjectLabel); //FieldLabelForLookupField, objectAPINameToPutLookupOn, relatedObjectPointedTo, relationshipLabelNameChildren
                            grantFieldEditAccess('Flowdometer_User', sObjectAPIName, fieldAPINameForLookupToFlow); //permission set, objectAPINameWLookup, LookupFieldAPIName
                    }
            }

            // Update the isRelationshipAvailable based on both checks
            isRelationshipAvailable = isLookupToSObjectAvailable && isLookupToFlowAvailable;
        }
        if(isRelationshipAvailable){
            String fieldAPIName = fieldAPINameForLookupToFlow;
            List<FieldDefinition> FieldDefinitionList = [SELECT QualifiedApiName,IsFieldHistoryTracked 
                                        FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = :sObjectAPIName 
                                        AND IsFieldHistoryTracked = true];

            for(FieldDefinition fd : FieldDefinitionList){
                historyEnabledFields.add(fd.QualifiedApiName);
            }
            // Check if we are out of available field history tracking 
            if(historyEnabledFields.size() == 20 && !historyEnabledFields.contains(fieldAPIName) && historyEnabledForObject){
                fieldHistoryStatus = HISTORY_ENABLED_HAS_NO_LIMITS; // Out of available field history tracking
            //Check if the field history is already enabled for this field
            } else if(!historyEnabledFields.isEmpty() && historyEnabledFields.contains(fieldAPIName) && historyEnabledForObject){
                fieldHistoryStatus = HISTORY_ENABLED_ALREADY; // Field history is already enabled for this field
            // Check if the field history is not enabled for this field and we are not out of available field history tracking
            } else if(historyEnabledForObject && !historyEnabledFields.contains(fieldAPIName) && historyEnabledFields.size() < 20){
                if(!Test.isRunningTest()){
                    MetadataService.enableFieldHistoryTracking(sObjectAPIName, fieldAPIName);
                }
                fieldHistoryStatus = HISTORY_ENABLED_HAS_LIMITS; // Field history is not enabled for this field but we are not out of available field history tracking
            // Check if the field history is not enabled for this field and we are out of available field history tracking
            } else if(!historyEnabledForObject){
                if(!Test.isRunningTest()){
                    MetadataService.enableFieldHistoryTracking(sObjectAPIName, fieldAPIName);
                }
                fieldHistoryStatus = HISTORY_NOT_ENABLED_EARLIER_BUT_ENABLED_NOW;
            } else {
                fieldHistoryStatus = '';
            }
        }
        System.debug(fieldHistoryStatus);
        return fieldHistoryStatus;
    }

    //This method is used to create the Listener record
    @AuraEnabled
    public static String createListenerRecord(Flowdometer__Listener__c newRecord){
        newRecord.Flowdometer__Last_Execution_On__c = Datetime.now();
        insert newRecord;
        return newRecord.Id;
    }
    
}