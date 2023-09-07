//force-app\main\default\classes\ListenerFlowController.cls
global with sharing class ListenerFlowController {
    @AuraEnabled
    global String varCurrentFieldTracked;
    @AuraEnabled
    global String varCurrentFieldValue;
    @AuraEnabled
    global String varCurrentObjectID;
    @AuraEnabled
    global String varNameofTrackedRecord;
    @AuraEnabled
    global Boolean varTerminalStage;
    @AuraEnabled
    global String varTrackedCustomObjectName;
    @AuraEnabled
    global Datetime varEditStartTime;
    @AuraEnabled
    global Datetime varEditEndTime;
    @AuraEnabled
    global String varType;
    @AuraEnabled
    global Id varHistoryRecordId;
    private static Map<Id, List<SObject>> historyRecordsMap;

    // Inner class for ListenerFlowLatestResponse params to flow
    global class ListenerFlowLatestResponse {
        @InvocableVariable
        global Boolean isCheckSuccess;
        @InvocableVariable
        global Boolean hasRecords;
        @InvocableVariable
        global List<ListenerFlowController> lstListenerFlow;
        global ListenerFlowLatestResponse() {
            this.isCheckSuccess = true;
            this.hasRecords = false;
            this.lstListenerFlow = new List<ListenerFlowController>();
        }
    }

    // Called by: parseRecordsToFlow
    // Set the booleans and where clause for constructSOQLQuery
    public static Map<String, Object> getQueryModifiers(Flowdometer__Listener__c listenerConfig) {
        Map<String, Object> queryModifiers = new Map<String, Object>();
        queryModifiers.put('includeOrderBy', true);  // Always include ORDER BY
        queryModifiers.put('includeLimit', true);  // Always include LIMIT

        // Generate the whereClause
        String whereClause = 'CreatedDate >= ';
        if (listenerConfig.Flowdometer__Last_Execution_On__c != null) {
            whereClause += '\'' + listenerConfig.Flowdometer__Last_Execution_On__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '\'';
        } else {
            whereClause += 'LAST_N_YEARS:3';  // Default to the last 3 years if no last execution date
        }
        queryModifiers.put('whereClause', whereClause);

        return queryModifiers;
    }

    // Called by: getLatestHistoryValues
    // This method returns a boolean value of whether the object passed in is a custom object or not.
    public static Boolean isCustomObject(String objectname) {
        SObjectType objToken = Schema.getGlobalDescribe().get(objectname);
        return (objToken != null && objToken.getDescribe().isCustom());
    }

    // This method returns a string value of the object passed in. If the object is null, it returns an empty string.
    public static String getStringNotNull(Object valueObj) {
        if (valueObj == null)
            return '';
        return String.valueOf(valueObj);
    }

    // Called by: parseRecordsToFlow
    // This method returns a map of the latest history values for the parent records passed in. It takes in a set of parent record ids and a listener flow record. It returns a map of the parent record ids and a list of history records for each parent record id.
    public static Map<Id, List<SObject>> getLatestHistoryValues(
        Set<Id> mParent,
        Listener__c listenerConfig,
        Map<String, Boolean> queryModifiers
    ) {
        String fieldValue = 'created';
        String objName = listenerConfig.Object_Name__c;
        String fieldName = listenerConfig.Field_To_Track__c;
        DateTime lastCheck = listenerConfig.Last_Execution_On__c;
        String objectSuffix = '__c';
        String objHistoryName = (objName == 'Opportunity')
            ? 'OpportunityFieldHistory'
            : (objName.contains(objectSuffix)
                ? (objName.substring(0, objName.length() - objectSuffix.length()) +
                    '__History')
                : (objName + 'History'));
        String parentFieldName = isCustomObject(objName)
            ? 'ParentId'
            : (objName + 'Id');
        Set<Id> parentIds = mParent;
        Map<Id, SObject> historyRecordValues = new Map<Id, SObject>();
        // String queryStr =
        //     'SELECT Id, Field, OldValue, NewValue, CreatedDate, ' +
        //     parentFieldName +
        //     ' FROM ' +
        //     objHistoryName +
        //     ' WHERE (Field =:fieldValue OR Field =:fieldName) AND ' +
        //     parentFieldName +
        //     ' IN :parentIds AND CreatedDate >= :lastCheck ORDER BY ' +
        //     parentFieldName +
        //     ', CreatedDate ASC';
        // Modify queryStr based on queryModifiers
        String queryStr = 'SELECT Id, Field, OldValue, NewValue, CreatedDate, ' + parentFieldName +
            ' FROM ' + objHistoryName +
            ' WHERE (Field =:fieldValue OR Field =:fieldName) AND ' +
            parentFieldName + ' IN :parentIds AND CreatedDate >= :lastCheck';

        if (queryModifiers.get('includeOrderBy')) {
        queryStr += ' ORDER BY ' + parentFieldName + ', CreatedDate ASC';
        }

        if (queryModifiers.get('includeLimit')) {
        queryStr += ' LIMIT 10000';  // or whatever your limit is
        }
        Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
        for (SObject obj : Database.query(queryStr)) {
            Id parentId = (Id)obj.get(parentFieldName);
            if (historyRecordsMap.containsKey(parentId)) {
                historyRecordsMap.get(parentId).add(obj);
            } else {
                historyRecordsMap.put(parentId, new List<SObject>{obj});
            }
        }
        // Sort by CreatedDate and then by Id
        for (Id parentId : historyRecordsMap.keySet()) {
            List<SObject> records = historyRecordsMap.get(parentId);
            records.sort();
        }
        Set<Id> oneHistoryParentIds = new Set<Id>();
        Map<Id, SObject> createdHistoryMap = new Map<Id, SObject>();
        for (Id parentId : historyRecordsMap.keySet()) {
            List<SObject> tempHistoryLst = historyRecordsMap.get(parentId);
            if (tempHistoryLst.size() == 1) {
                oneHistoryParentIds.add(parentId);
            }
        }
        if (!oneHistoryParentIds.isEmpty()) {
            String parentTrackedField = isCustomObject(objName)
                ? ('Parent.' + fieldName)
                : (objName + '.' + fieldName);
            String parentQueryStr =
                'SELECT Id, Field, OldValue, NewValue, CreatedDate, ' +
                parentTrackedField +
                ', ' +
                parentFieldName +
                ' FROM ' +
                objHistoryName +
                ' WHERE Field =: fieldValue AND ' +
                parentFieldName +
                '=: oneHistoryParentIds' +
                ' ORDER BY ' +
                parentFieldName +
                ', CreatedDate ASC';
            for (SObject sObj : Database.query(parentQueryStr)) {
                Id parentId = (Id)sObj.get(parentFieldName);
                createdHistoryMap.put(parentId, sObj);
            }
        }
        if (!createdHistoryMap.isEmpty()) {
            for (Id parentId : createdHistoryMap.keySet()) {
                if (historyRecordsMap.containsKey(parentId)) {
                    List<SObject> tempList = historyRecordsMap.get(parentId);
                    tempList.remove(tempList.size() - 1);
                    tempList.add(createdHistoryMap.get(parentId));
                    historyRecordsMap.put(parentId, tempList);
                }
            }
        }
        return historyRecordsMap;
    }

    // Called by: parseRecordsToFlow
    // This method takes in a listener flow record, a map of parent record ids and a list of history records for each parent record id, a map of goal step records, and a map of parent record ids and parent records. It returns a response object with a list of listener flow controller objects.
    @TestVisible
    private static void preparingResponse(
        ListenerFlowLatestResponse result,
        Map<Id, List<SObject>> historyRecordsMap,
        Listener__c listenerConfig,
        Map<Id, Map<String, Id>> goalStepRecsMap,
        Map<Id, SObject> sObjectMap
    ) {
        for (Id parentRecId : historyRecordsMap.keySet()) {
            Integer count = 0;
            for (SObject SObj : historyRecordsMap.get(parentRecId)) {
                ListenerFlowController trackFlowObj = new ListenerFlowController();
                trackFlowObj.varHistoryRecordId = (Id)SObj.get('Id');  // Set the history record ID
                // ... (existing code)
                result.lstListenerFlow.add(trackFlowObj);
                count++;
            }            
        }
        result.hasRecords = !historyRecordsMap.isEmpty();
    }

    // This method returns a string that is used in a SOQL query to filter records based on the last execution date of the listener flow.
    // Main method that calls getQueryModifiers, getWhereClause, getLatestHistoryValues, preparingResponse
    @InvocableMethod(label='Query & Parse History Records', description='Collect history tracking records after you have turned on history tracking', category='ListenerFlowController')
    public static List<ListenerFlowLatestResponse> parseRecordsToFlow(List<ListenerFlowLatestRequest> listenerConfigList, Listener__c listenerConfig) {
        ListenerFlowLatestResponse response = new ListenerFlowLatestResponse();
        Set<Id> targetRecords = new Set<Id>();
        Map<Id, SObject> sObjectMap = new Map<Id, SObject>();
        Map<Id, List<SObject>> latestHistory = new Map<Id, List<SObject>>();
        Map<Id, Map<String, Id>> goalStepRecsMap = new Map<Id, Map<String, Id>>();

        if (listenerConfigList.isEmpty()) {
            return null;
        }

        // From the batch, we are passing only one Listener Flow record.
        Listener__c listenerConfigRec = listenerConfigList[0].listenerConfig;

        try {
            // Get query modifiers based on the listenerConfigRec
            Map<String, Boolean> queryModifiers = getQueryModifiers(listenerConfigRec);

            String parentNameField = listenerConfigRec.Object_Name__c != null &&
                listenerConfigRec.Object_Name__c == 'Case' ? 'CaseNumber' : 'Name';
            String terminalStageField = listenerConfigRec.TerminalStage__c != null ? listenerConfigRec.TerminalStage__c : '';

            String queryString = 'SELECT Id';
            if (String.isNotBlank(parentNameField)) {
                queryString += ', ' + parentNameField;
            }
            if (String.isNotBlank(terminalStageField)) {
                queryString += ', ' + terminalStageField;
            }
            queryString += ' FROM ' + listenerConfigRec.Object_Name__c +
                ' WHERE ' + getWhereClause(listenerConfigRec, queryModifiers.get('includeLastModifiedCheck'));

            for (SObject sob : Database.query(queryString)) {
                targetRecords.add(sob.Id);
                sObjectMap.put(sob.Id, sob);
            }

            // Pass queryModifiers to getLatestHistoryValues
            latestHistory = getLatestHistoryValues(targetRecords, listenerConfigRec, queryModifiers);

            preparingResponse(response, latestHistory, listenerConfigRec, goalStepRecsMap, sObjectMap);

            listenerConfigRec.Error_Message__c = '';
        } catch (Exception ex) {
            response.isCheckSuccess = false;
            listenerConfigRec.Error_Message__c =
                'Error: ' +
                ex.getMessage() +
                ' Trace: ' +
                ex.getStackTraceString();
        }

        update listenerConfigRec;
        return new List<ListenerFlowLatestResponse>{ response };
    }
}
