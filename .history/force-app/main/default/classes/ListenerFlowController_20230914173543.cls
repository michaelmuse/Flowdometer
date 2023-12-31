/*
  Class: ListenerFlowController
  Path: force-app\main\default\classes\ListenerFlowController.cls
  
  Core Methods:
  - ListenerFlowLatestResponse(): Initializes the response object.
    - Return: ListenerFlowLatestResponse
    - Variables in Scope: isCheckSuccess, hasRecords, lstListenerFlow
    - Lines: 54-59

  - getQueryModifiers(Listener__c listenerConfig): Modifies queries based on listener config.
    - Return: Map<String, Object>
    - Variables in Scope: queryModifiers, whereClause
    - Lines: 65-80

  - getLatestHistoryValues(List<Id> mParent, Listener__c listenerConfig, Map<String, Object> queryModifiers): Fetches the latest history records.
    - Return: HistoryValuesResult (wrapper class with historyRecordsMap and sortingDateTimeMap)
    - Variables in Scope: sortingDateTimeMap, fieldValue, objName, fieldName, objectSuffix, objHistoryName, parentFieldName, queryStr
    - Lines: 138-238

  - parseRecordsToFlow(List<ListenerFlowLatestRequest> listenerConfigList): Transforms records for the flow.
    - Return: List<ListenerFlowLatestResponse>
    - Variables in Scope: listenerConfigRec, targetRecordIds, queryModifiers, responseList, targetRecords, sObjectMap, historyRecordsMap, sortingDateTimeMap
    - Lines: 267-315
    - Invokes: 
        1. getQueryModifiers() 
        2. getLatestHistoryValues()
        3. preparingResponse()

  Utility Methods:
  - isCustomObject(String objectname): Checks if an object is a custom object.
    - Return: Boolean
    - Variables in Scope: objToken
    - Lines: 84-87

  - getStringNotNull(Object valueObj): Converts an object to a non-null string.
    - Return: String
    - Variables in Scope: valueObj
    - Lines: 91-95

  Custom Datetime Sorting:
  - CustomDatetimeSort(SObject record): Constructor for custom datetime sorting.
    - Return: void
    - Variables in Scope: record
    - Lines: 100-104

  - compareTo(Object compareTo): Custom comparison logic.
    - Return: Integer
    - Variables in Scope: compareToRecord, thisDate, otherDate, thisMillis, otherMillis
    - Lines: 106-122

  Control Flow:
  - Various 'if' and 'for' statements for control flow. (Lines: 117-119, 169-172, 176-179, 191-195, 293-298)
*/

global with sharing class ListenerFlowController {
    //This is a managed package so we need global modifiers
    @AuraEnabled global String varCurrentFieldTracked;
    @AuraEnabled global String varCurrentFieldValue;
    @AuraEnabled global String varCurrentObjectID;
    @AuraEnabled global Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
    global static Map<Id, List<Datetime>> sortingDateTimeMap = new Map<Id, List<Datetime>>();
    @AuraEnabled global String varNameofTrackedRecord;
    @AuraEnabled global Boolean varTerminalStage;
    @AuraEnabled global String varTrackedCustomObjectName;
    @AuraEnabled global Datetime varEditStartTime;
    @AuraEnabled global Datetime varEditEndTime;
    @AuraEnabled global String varType;
    @AuraEnabled global Id varHistoryRecordId;
  
    // Inner class for ListenerFlowLatestResponse params to flow
    @TestVisible
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
    // Wrapper class to hold the result of getLatestHistoryValues
    public class HistoryValuesResult {
        public Map<Id, List<SObject>> historyRecordsMap;
        public Map<Id, List<Datetime>> sortingDateTimeMap;

        public HistoryValuesResult(Map<Id, List<SObject>> historyRecordsMap, Map<Id, List<Datetime>> sortingDateTimeMap) {
            this.historyRecordsMap = historyRecordsMap;
            this.sortingDateTimeMap = sortingDateTimeMap;
        }
    }
    
    // Called by: parseRecordsToFlow
    // Set the booleans and where clause for parseRecordsToFlow
    @TestVisible
    private static Map<String, Object> getQueryModifiers(Listener__c listenerConfig) {
        Map<String, Object> queryModifiers = new Map<String, Object>();
        queryModifiers.put('includeOrderBy', true);  // Always include ORDER BY
        queryModifiers.put('includeLimit', true);  // Always include LIMIT
    
        // Generate the whereClause
        String whereClause = 'LastModifiedDate >= ';
        if (listenerConfig.Last_Execution_On__c != null) {
            whereClause += '\'' + listenerConfig.Last_Execution_On__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '\'';
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
    @TestVisible
    private static String getStringNotNull(Object valueObj) {
        if (valueObj == null)
            return '';
        return String.valueOf(valueObj);
    }
  
    // Called by: getLatestHistoryValues
    // Comparator Class for Date sorting by milliseconds
    public class CustomDatetimeSort implements Comparable {
        public SObject record;
  
        public CustomDatetimeSort(SObject record) {
            this.record = record;
        }
  
        public Integer compareTo(Object compareTo) {
            CustomDatetimeSort compareToRecord = (CustomDatetimeSort)compareTo;
  
            Datetime thisDate = (Datetime)record.get('CreatedDate');
            Datetime otherDate = (Datetime)compareToRecord.record.get('CreatedDate');
  
            Long thisMillis = thisDate.getTime();
            Long otherMillis = otherDate.getTime();
  
            if (thisMillis > otherMillis) {
                return 1;
            } else if (thisMillis < otherMillis) {
                return -1;
            } else {
                return 0;
            }
        }
    }    

    // Define the ListenerFlowLatestRequest class only once
    global class ListenerFlowLatestRequest {
        // Request class members here
        @InvocableVariable
        global Listener__c listenerConfig;
    }

    // Define the listenerConfigList variable
    public static List<ListenerFlowLatestRequest> listenerConfigList;  

    // Called by: parseRecordsToFlow
    // This method returns a map of the latest history values for the parent records passed in. It takes in a set of parent record ids and a listener flow record. It returns a map of the parent record ids and a list of history records for each parent record id.
    @TestVisible
    private static HistoryValuesResult getLatestHistoryValues(List<Id> mParent, Listener__c listenerConfig, Map<String, Object> queryModifiers) {
        sortingDateTimeMap.clear(); 
        String fieldValue = 'created';
        String objName = listenerConfig.Object_Name__c;
        String fieldName = listenerConfig.Field_To_Track__c;
        String objectSuffix = '__c';
        String objHistoryName = (objName == 'Opportunity')
            ? 'OpportunityFieldHistory'
            : (objName.contains(objectSuffix)
                ? (objName.substring(0, objName.length() - objectSuffix.length()) + '__History')
                : (objName + 'History'));
        String parentFieldName = isCustomObject(objName) ? 'ParentId' : (objName + 'Id');
  
        // Construct the query string based on queryModifiers
        String queryStr = 'SELECT Id, Field, OldValue, NewValue, CreatedDate, ' + parentFieldName +
        ' FROM ' + objHistoryName +
        ' WHERE (Field =:fieldValue OR Field =:fieldName) AND ' +
        parentFieldName + ' IN :mParent AND ' + (String)queryModifiers.get('whereClause');
  
        if ((Boolean)queryModifiers.get('includeOrderBy')) {
            queryStr += ' ORDER BY ' + parentFieldName + ', CreatedDate ASC';
        }
  
        if ((Boolean)queryModifiers.get('includeLimit')) {
            queryStr += ' LIMIT 10000';
        }

        Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
        // Populate historyRecordsMap and sortingDateTimeMap
        for (SObject obj : Database.query(queryStr)) {
            Id parentId = (Id)obj.get(parentFieldName);
            Datetime createdDate = (Datetime)obj.get('CreatedDate');
        
            
            // Populate historyRecordsMap
            if (historyRecordsMap.containsKey(parentId)) {
                historyRecordsMap.get(parentId).add(obj);
            } else {
                historyRecordsMap.put(parentId, new List<SObject>{obj});
            }
            
            // Populate sortingDateTimeMap
            if (sortingDateTimeMap.containsKey(parentId)) {
                sortingDateTimeMap.get(parentId).add(createdDate);
            } else {
                sortingDateTimeMap.put(parentId, new List<Datetime>{createdDate});
            }
        }
        if (!historyRecordsMap.isEmpty()) {
            for (Id parentId : historyRecordsMap.keySet()) {
                List<SObject> histories = historyRecordsMap.get(parentId);
                fieldValue = String.valueOf(histories[0].get(fieldName));
                break;  // exit after one iteration as we just want to populate fieldValue
            }
        }

        // Sort by CreatedDate and then by Id
        for (Id parentId : sortingDateTimeMap.keySet()) {
            List<Datetime> dateTimes = sortingDateTimeMap.get(parentId);
            dateTimes.sort();
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
        // Handle the createdHistoryMap logic
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
  
        // Sort by CreatedDate and then by Id
        for (Id parentId : sortingDateTimeMap.keySet()) {
            List<Datetime> dateTimes = sortingDateTimeMap.get(parentId);
            dateTimes.sort();
        }

        // Return both maps in a wrapper class
        return new HistoryValuesResult(historyRecordsMap, sortingDateTimeMap);
    }
  
    // Called by: parseRecordsToFlow 
    // This method takes in a listener flow record, a map of parent record ids and a list of history records for each parent record id, a map of goal step records, and a map of parent record ids and parent records. It returns a response object with a list of listener flow controller objects.
    @TestVisible
    public static void preparingResponse(ListenerFlowLatestResponse response, Map<Id, List<SObject>> historyRecordsMap, Listener__c listenerConfig, Map<String, SObject> sObjectMap, Map<Id, List<Datetime>> sortingDateTimeMap) {
        for (Id parentRecId : sortingDateTimeMap.keySet()) {
            Integer count = 0;
            for (Datetime dt : sortingDateTimeMap.get(parentRecId)) {  // This should now be a List<Datetime>
                ListenerFlowController trackFlowObj = new ListenerFlowController();
                SObject SObj = historyRecordsMap.get(parentRecId)[count];  // Fetch the corresponding SObject
                trackFlowObj.varHistoryRecordId = (Id)SObj.get('Id');
                trackFlowObj.varCurrentFieldTracked = listenerConfig.Field_To_Track__c;
                response.lstListenerFlow.add(trackFlowObj);
                count++;
            }
        }
        response.hasRecords = !historyRecordsMap.isEmpty();  
    }

    @InvocableMethod(label='Query & Parse History Records', description='', category='ListenerFlowController')
    public static List<ListenerFlowLatestResponse> parseRecordsToFlow(List<ListenerFlowLatestRequest> listenerConfigList) {
        // Initialize response list and a single response object
        List<ListenerFlowLatestResponse> responseList = new List<ListenerFlowLatestResponse>();  
        ListenerFlowLatestResponse response = new ListenerFlowLatestResponse();
        
        // Early exit if the input list is empty
        if (listenerConfigList.isEmpty()) return responseList;
        
        // Declare targetRecords and targetRecordIds within the method scope
        Set<Id> targetRecords = new Set<Id>();  // <-- Correctly declared here
        List<Id> targetRecordIds;  // <-- Declare this variable here, no need to initialize here if you're initializing later
        
        // Initialize other variables
        Map<String, SObject> sObjectMap = new Map<String, SObject>();
        Listener__c listenerConfigRec = listenerConfigList[0].listenerConfig;
        
        // Get query modifiers
        Map<String, Object> queryModifiers = getQueryModifiers(listenerConfigRec);
        
        try {
            // Set parentNameField and terminalStageField
            String parentNameField = (listenerConfigRec.Object_Name__c != NULL && listenerConfigRec.Object_Name__c == 'Case') ? 'CaseNumber' : 'Name';
            String terminalStageField = (listenerConfigRec.TerminalStage__c != NULL) ? listenerConfigRec.TerminalStage__c : '';
            String queryString = 'SELECT Id';
            
            if (String.isNotBlank(parentNameField)) queryString += ', ' + parentNameField;
            if (String.isNotBlank(terminalStageField)) queryString += ', ' + terminalStageField;
            
            queryString += ' FROM ' + listenerConfigRec.Object_Name__c +  ' WHERE ' + (String)queryModifiers.get('whereClause');
    
            // Populate targetRecords and sObjectMap
            for (SObject sob : Database.query(queryString)) {
                targetRecords.add(sob.Id);
                sObjectMap.put(sob.Id, sob);
            }
            
            // Convert targetRecords to targetRecordIds
            targetRecordIds = new List<Id>(targetRecords);  // <-- Adjusted this line
           
    
            // Get latest history values
            HistoryValuesResult historyResult = getLatestHistoryValues(targetRecordIds, listenerConfigRec, queryModifiers);
            Map<Id, List<SObject>> historyRecordsMap = historyResult.historyRecordsMap;
            Map<Id, List<Datetime>> sortingDateTimeMap = historyResult.sortingDateTimeMap;
    
            // Prepare the response
            preparingResponse(response, historyRecordsMap, listenerConfigRec, sObjectMap, sortingDateTimeMap);
    
            // Clear previous errors
            listenerConfigRec.Error_Message__c = '';
            
        } catch (Exception e) {
            // Handle exceptions and update listenerConfigRec
            response.isCheckSuccess = false;
            listenerConfigRec.Error_Message__c = 'Error: ' + e.getMessage() + ' Trace: ' + e.getStackTraceString();
            update listenerConfigRec;
            responseList.add(response);
        }
        
        return responseList;
    }
}