/*
Class: ListenerFlowController (My Controller)
Path: force-app\main\default\classes\ListenerFlowController.cls
This class contains utility methods and the core logic for the Listener Flow.

Core Methods:
- ListenerFlowLatestResponse(): Constructor that initializes the response object. (Lines: 51-56)
- getQueryModifiers(Listener__c listenerConfig): Modifies queries based on custom object types. (Lines: 62-77)
- Invokes: getQueryModifiers()
- getLatestHistoryValues(...): Retrieves the latest history records. (Lines: 125-225)
- Invokes: isCustomObject()
- parseRecordsToFlow(List<ListenerFlowLatestRequest> listenerConfigList): Transforms raw records to the format expected by the flow. (Lines: 264-312)
- Invokes: getQueryModifiers(), getLatestHistoryValues(), preparingResponse()

Utility Methods:
- isCustomObject(String objectname): Determines if an object is a custom Salesforce object. (Lines: 81-84)
- Invokes: isCustomObject()
- getStringNotNull(Object valueObj): Safely converts an Object to its String representation, returning an empty string if null. (Lines: 88-92)
- Invokes: getStringNotNull()

Custom Datetime Sorting:
- CustomDatetimeSort(SObject record): Constructor for custom datetime sorting. (Lines: 97-101)
- compareTo(Object compareTo): Method for custom comparison. (Lines: 103-119)

Control Flow:
- Various 'if' and 'for' statements for conditional and iterative logic. (Lines: 114-116, 156-159, 163-166, 178-182, 290-295)

The methods are encapsulated and independent, making them good candidates for unit testing.
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
  
    // Called by: parseRecordsToFlow
    // Set the booleans and where clause for parseRecordsToFlow
    @TestVisible
    private static Map<String, Object> getQueryModifiers(Listener__c listenerConfig) {
        Map<String, Object> queryModifiers = new Map<String, Object>();
        queryModifiers.put('includeOrderBy', true);  // Always include ORDER BY
        queryModifiers.put('includeLimit', true);  // Always include LIMIT
  
        // Generate the whereClause
        String whereClause = 'CreatedDate >= ';
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
    private static Map<Id, List<SObject>> getLatestHistoryValues(List<Id> mParent, Listener__c listenerConfig, Map<String, Object> queryModifiers) {
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
    public static void preparingResponse(
        ListenerFlowLatestResponse result, 
        Map<Id, List<SObject>> historyRecordsMap, 
        Listener__c listenerConfig, 
        Map<Id, SObject> goalStepRecsMap, 
        Map<Id, SObject> sObjectMap,
        Map<Id, List<Datetime>> sortingDateTimeMap  // Added this parameter
    ) {
        for (Id parentRecId : sortingDateTimeMap.keySet()) {
            Integer count = 0;
            for (Datetime dt : sortingDateTimeMap.get(parentRecId)) {
                ListenerFlowController trackFlowObj = new ListenerFlowController();
                SObject SObj = historyRecordsMap.get(parentRecId)[count];  // Fetch the corresponding SObject
                trackFlowObj.varHistoryRecordId = (Id)SObj.get('Id');
                trackFlowObj.varCurrentFieldTracked = listenerConfig.Field_To_Track__c;
                result.lstListenerFlow.add(trackFlowObj);
                count++;
            }
        }
        result.hasRecords = !historyRecordsMap.isEmpty();
    }

    // Process history tracking records and return results
    @InvocableMethod(label='Query & Parse History Records' description='Get History records for the tracked object' category='ListenerFlowController')
    public static List<ListenerFlowLatestResponse> parseRecordsToFlow(List<ListenerFlowLatestRequest> listenerConfigList) {
        ListenerFlowLatestResponse response = new ListenerFlowLatestResponse();
        
        // Declare missing variables
        List<Id> targetRecords = new List<Id>();
        Map<Id, SObject> sObjectMap = new Map<Id, SObject>();
        Map<Id, SObject> goalStepRecsMap = new Map<Id, SObject>(); // Assuming it's a Map, adjust as needed

        Listener__c listenerConfig = listenerConfigList[0].listenerConfig;

        try {
            // Assuming getQueryModifiers is defined in this class or imported
            Map<String, Object> queryModifiers = getQueryModifiers(listenerConfig);

            String parentNameField = listenerConfig.Object_Name__c != null &&
                listenerConfig.Object_Name__c == 'Case' ? 'CaseNumber' : 'Name';
            String terminalStageField = listenerConfig.TerminalStage__c != null ? listenerConfig.TerminalStage__c : '';

            String queryString = 'SELECT Id';
            if (String.isNotBlank(parentNameField)) {
                queryString += ', ' + parentNameField;
            }
            if (String.isNotBlank(terminalStageField)) {
                queryString += ', ' + terminalStageField;
            }
            queryString += ' FROM ' + listenerConfig.Object_Name__c +
                ' WHERE ' + (String) queryModifiers.get('whereClause'); // Use whereClause from queryModifiers

            for (SObject sob : Database.query(queryString)) {
                targetRecords.add(sob.Id);
                sObjectMap.put(sob.Id, sob);
            }

            Map<Id, List<SObject>> latestHistory = getLatestHistoryValues(targetRecords, listenerConfig, queryModifiers);
            preparingResponse(response, latestHistory, listenerConfig, goalStepRecsMap, sObjectMap, sortingDateTimeMap);

            listenerConfig.Error_Message__c = '';
        } catch (Exception ex) {
            response.isCheckSuccess = false;
            listenerConfig.Error_Message__c =
                'Error: ' +
                ex.getMessage() +
                ' Trace: ' +
                ex.getStackTraceString();
        }

        update new List<Listener__c>{listenerConfig};
        return new List<ListenerFlowLatestResponse>{response};
    }

}