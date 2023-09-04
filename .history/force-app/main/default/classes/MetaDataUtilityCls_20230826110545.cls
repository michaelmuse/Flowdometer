public with sharing class MetaDataUtilityCls {
    public static final String HISTORY_ENABLED_HAS_NO_LIMITS = 'HISTORY_ENABLED_HAS_NO_LIMITS';
    public static final String HISTORY_NOT_ENABLED_EARLIER_BUT_ENABLED_NOW = 'HISTORY_NOT_ENABLED_EARLIER_BUT_ENABLED_NOW';
    public static final String HISTORY_ENABLED_ALREADY = 'HISTORY_ENABLED_ALREADY';
    public static final String HISTORY_ENABLED_HAS_LIMITS = 'HISTORY_ENABLED_HAS_LIMITS';
    public static Map<String, String> fieldNameAPISetMap = new Map<String, String>();
    public static Map<String,String> relatedlookupMap = new Map<String,String>();
    public static Map<String,String> lookUpAPINameMap = new Map<String,String>();
    public static Boolean isRelationshipAvailable = FALSE;

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

    public static List<String> getSortedKeySet(Map<String, String> objectAPIToLabelMap){
        List<String> keySetLst = new List<String>();
        keySetLst.addAll(objectAPIToLabelMap.keySet());
        keySetLst.sort();
        return keySetLst;
    }
    
	public static void grantFieldEditAccess(String permissionSetName, String objectApiName, String fieldApiName) {
        try {
            MetadataService.MetadataPort service = MetadataService.createService();
            MetadataService.PermissionSet permissionSet = (MetadataService.PermissionSet) service.readMetadata(
                'PermissionSet', new String[] { permissionSetName }).getRecords()[0];
            MetadataService.PermissionSetFieldPermissions fieldPermission = new MetadataService.PermissionSetFieldPermissions();
            fieldPermission.field = objectApiName+'.'+fieldApiName;
            fieldPermission.editable = true;
            fieldPermission.readable = true;
            permissionSet.fieldPermissions.add(fieldPermission);
            List<MetadataService.SaveResult> results = service.updateMetadata(new MetadataService.Metadata[] { permissionSet });
			MetadataService.handleSaveResults(results[0]);
        } catch (Exception e) {
            System.debug('An error occurred: ' + e.getMessage());
        }
    }    

    // This method check that selected field is history tracking Enable or not 
    // if in case field history not enable then shows the message that 'Enable the History tracking'
    @AuraEnabled(Cacheable=true)  
    public static String checkFieldHistoryStatus(string sObjectName, string fieldName){
        Set<String> historyEnabledFields = new Set<String>();
        String fieldHistoryStatus = '';
        Set<String> stdObjects = new Set<String>{'Account', 'Contact', 'Lead','Opportunity','Case'};
        Boolean historyEnabledForObject = false;
        
        getLookupField('Flowdometer__Flow__c');
        isRelationshipAvailable = relatedlookupMap.containsKey(sObjectName) ? TRUE : FALSE;
        if(stdObjects.contains(sObjectName) || sObjectName.contains('__c')){
            if(!Test.isRunningTest()){
                historyEnabledForObject = MetadataService.validateHistoryEnabled(sObjectName);
            }
        } else {
            historyEnabledForObject = true;
        }

        if(!isRelationshipAvailable){
            String fieldLabel = sObjectName.contains('__c') ? sObjectName.replace('__c','') : sObjectName;
            if(!Test.isRunningTest()){
                MetadataService.createLookupField(fieldLabel, 'Flowdometer__Flow__c', sObjectName);
                String fieldAPIName = sObjectName.contains('__c') ? sObjectName.replace(' ', '_') : sObjectName.replace(' ', '_') + '__c';
                grantFieldEditAccess('Flowdometer_User','Flowdometer__Flow__c',fieldAPIName);
            }
            isRelationshipAvailable = TRUE;
        }
        if(isRelationshipAvailable){
            String fieldAPIName = fieldName;
            List<FieldDefinition> FieldDefinitionList = [SELECT QualifiedApiName,IsFieldHistoryTracked 
                                        FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = :sObjectName 
                                        AND IsFieldHistoryTracked = true];

            for(FieldDefinition fd : FieldDefinitionList){
                historyEnabledFields.add(fd.QualifiedApiName);
            }
            if(historyEnabledFields.size() == 20 && !historyEnabledFields.contains(fieldAPIName) && historyEnabledForObject){
                fieldHistoryStatus = HISTORY_ENABLED_HAS_NO_LIMITS;
            } else if(!historyEnabledFields.isEmpty() && historyEnabledFields.contains(fieldAPIName) && historyEnabledForObject){
                fieldHistoryStatus = HISTORY_ENABLED_ALREADY;
            } else if(historyEnabledForObject && !historyEnabledFields.contains(fieldAPIName) && historyEnabledFields.size() < 20){
                if(!Test.isRunningTest()){
                    MetadataService.enableFieldHistoryTracking(sObjectName, fieldName);
                }
                fieldHistoryStatus = HISTORY_ENABLED_HAS_LIMITS;
            } else if(!historyEnabledForObject){
                if(!Test.isRunningTest()){
                    MetadataService.enableFieldHistoryTracking(sObjectName, fieldName);
                }
                fieldHistoryStatus = HISTORY_NOT_ENABLED_EARLIER_BUT_ENABLED_NOW;
            } else {
                fieldHistoryStatus = '';
            }
        }
        return fieldHistoryStatus;
    }

    @AuraEnabled
    public static String createListenerRecord(Flowdometer__Listener__c newRecord){
        newRecord.Flowdometer__Last_Execution_On__c = Datetime.now();
        insert newRecord;
        return newRecord.Id;
    }
}