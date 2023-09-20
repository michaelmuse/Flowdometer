/*
Class: ListenerFlowController
Path: force-app\main\default\classes\ListenerFlowController.cls

Purpose:
This managed class primarily aids in the real-time monitoring and recording of changes occurring in specified fields of Salesforce objects, driven by configurations in the Listener__c custom object. 
Its critical function is to construct SOQL queries intelligently, fetch and sort historical records, and encapsulate these results in a list of ListenerFlowLatestResponse objects.

The strength of this class lies in its dynamic response to Invocable Actions called in Salesforce Flows via the parseRecordsToFlow method. 
It performs two significant queries based on the Listener__c.Last_Execution_On__c field in the Listener__c custom object.

If the Listener__c.Last_Execution_On__c field is null (indicating the query has not run before), the class queries all records of the object type, as specified by Listener.Object_Name__c. 
It then queries all corresponding history records that match Listener__c.Field_To_Track__c, effectively syncing the "Created" history records with the values from the parent (tracked) record. 
The results provide a comprehensive history of the creation and changes to the specified field for each record.

If the Listener__c.Last_Execution_On__c is populated (indicating the query has run before), it executes similar queries but specifically focuses on records created since Listener__c.Last_Execution_On__c.

The class then returns the complete or updated history to the flow, hence providing a robust and efficient way to monitor field changes of Salesforce objects based on listener configurations.

Exception Handling:
Upon experiencing any exceptions during execution, the class updates 'Error_Message__c' field on Listener__c and sets 'isCheckSuccess' to false in the response.

Note: Optionally includes terminal stage and parent name fields in the output if specified in the Listener__c objects.

Core Methods:

ListenerFlowLatestResponse(): Initializes the response object.

Return: ListenerFlowLatestResponse object
Variables in Scope: isCheckSuccess, hasRecords, lstListenerFlow
Lines: 57-62
getQueryModifiers(Boolean isHistoryQuery, DateTime lastExecutionOn): Modifies queries based on listener config.

Return: Map<String, Object>
Variables in Scope: queryModifiers, whereClause
Lines: 417-432
getLatestHistoryValues(List<Id> targetRecordIds, Listener__c listenerConfig, DateTime lastExecutionOn, ListenerFlowController controllerInstance, String objHistoryName, String parentIdField): Fetches the latest history records.

Return: HistoryValuesResult (Wrapper class with historyRecordsMap and sortingDateTimeMap)
Variables in Scope: sortingDateTimeMap, fieldValue, fieldName, objectSuffix, queryStr, historyRecordsMap
Lines: 1017-1174
parseRecordsToFlow(List<ListenerFlowLatestRequest> listenerConfigList): Transforms records for the flow.

Return: List<ListenerFlowLatestResponse>
Variables in Scope: listenerConfig, targetRecordIds, queryModifiers, responseList, targetRecords, sObjectMap, historyRecordsMap, sortingDateTimeMap
Lines: 1287-1433
Invokes:
ListenerFlowLatestResponse()
buildQuery()
getLatestHistoryValues()
preparingResponse()
Utility Methods:

isCustomObject(String objectname): Checks if an object is a custom object.

Return: Boolean
Variables in Scope: objToken
Lines: 470-473
getStringNotNull(Object valueObj): Converts an object to a non-null string.

Return: String
Variables in Scope: valueObj
Lines: 491-495
Custom Datetime Sorting:

CustomDatetimeSort(SObject record): Constructor for custom datetime sorting.

Return: void
Variables in Scope: record
Lines: 605-609
compareTo(Object compareTo): Custom comparison logic.

Return: Integer
Variables in Scope: compareToRecord, thisDate, otherDate, thisMillis, otherMillis
Lines: 611-628
Control Flow:

Various 'if' and 'for' statements for control flow. (Lines: 950-953, 994-998, 1165-1174, 1032-1034) 
*/

global with sharing class ListenerFlowController {
  //This is a managed package so we need global modifiers
  @AuraEnabled
  global String varCurrentFieldTracked;
  @AuraEnabled
  global String varCurrentFieldValue;
  @AuraEnabled
  global String varCurrentObjectID;
  @AuraEnabled
  public Map<Id, List<SObject>> historyRecordsMap;
  public Map<Id, List<Datetime>> sortingDateTimeMap;
  public Map<Id, SObject> parentRecordsMap = new Map<Id, SObject>();
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

  //Constructor class
  public ListenerFlowController() {
    // Initialize our collection of history records and the sorting map
    this.historyRecordsMap = new Map<Id, List<SObject>>();
    this.sortingDateTimeMap = new Map<Id, List<Datetime>>();
  }
  // Class for making editable history records
  public class EditableHistory {
    public String Id { get; set; }
    public String FieldValue { get; set; }
    public String OldValue { get; set; }
    public String NewValue { get; set; }
    public Datetime CreatedDate { get; set; }
  }
  // Wrapper class to hold the result of getLatestHistoryValues
  public class HistoryValuesResult {
    public Map<Id, List<SObject>> historyRecordsMap;
    public Map<Id, List<Datetime>> sortingDateTimeMap;

    public HistoryValuesResult(
      Map<Id, List<SObject>> historyRecordsMap,
      Map<Id, List<Datetime>> sortingDateTimeMap
    ) {
      this.historyRecordsMap = historyRecordsMap;
      this.sortingDateTimeMap = sortingDateTimeMap;
    }
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

    // Define the object name history variable
    private static String getHistoryObjectName(String objectName) {
      // Approach 1: Standard Objects
      Map<String, String> standardObjectToHistoryMap = new Map<String, String>{
        'Case' => 'CaseHistory',
        'Account' => 'AccountHistory',
        'Contact' => 'ContactHistory',
        'Lead' => 'LeadHistory',
        'Opportunity' => 'OpportunityFieldHistory'
      };
      if (standardObjectToHistoryMap.containsKey(objectName)) {
        return standardObjectToHistoryMap.get(objectName);
      }
  
      // Approach 2: Custom Objects (only if not a standard object)
      if (isCustomObject(objectName)) {
        return objectName + '__History';
      }
  
      // If no matching history object is found, return null or throw an exception.
      return null;
    }
    private static String getParentName(String objectName) {
      Map<String, String> objectToNameFieldMap = new Map<String, String> {
          'Case' => 'CaseNumber',
          'Solution' => 'SolutionNumber',
          'Contract' => 'ContractNumber'
      };
  
      if (objectToNameFieldMap.containsKey(objectName)) {
          return objectToNameFieldMap.get(objectName);
      }
  
      // Return 'Name' by default, because it's used by majority of standard objects and all custom objects
      return 'Name';
    }

  // Called by: getLatestHistoryValues
  // Comparator Class for SObject sorting primarily by CreatedDate and secondarily by ID
  public class CustomDatetimeSort implements Comparable {
    public SObject record;

    public CustomDatetimeSort(SObject record) {
      this.record = record;
    }

    public Integer compareTo(Object compareTo) {
      CustomDatetimeSort compareToRecord = (CustomDatetimeSort) compareTo;
  
      Datetime thisDate = (Datetime) this.record.get('CreatedDate');
      Datetime otherDate = (Datetime) compareToRecord.record.get('CreatedDate');
  
      Long thisMillis = thisDate.getTime();
      Long otherMillis = otherDate.getTime();
  
      if (thisMillis > otherMillis) {
          return 1;
      } else if (thisMillis < otherMillis) {
          return -1;
      } else {
          // if the CreatedDate is the same, use the ID as secondary sorting criterion
          ID thisID = (ID) this.record.get('Id');
          ID otherID = (ID) compareToRecord.record.get('Id');
  
          if (thisID > otherID) {
              return 1;
          } else if (thisID < otherID) {
              return -1;
          } else {
              return 0;
          }
      }
    }
  }

  // Define the ListenerFlowLatestRequest class
  global class ListenerFlowLatestRequest {
    @InvocableVariable
    global Listener__c listenerConfig;

    @InvocableVariable
    global DateTime lastExecutionOn;
  }

  // Define the listenerConfigList variable
  public static List<ListenerFlowLatestRequest> listenerConfigList;
  
// Section where we build and call the query ------------------------------------------------------
// ------------------------------------------------------------------------------------------------
  // Called by: getLatestHistoryValues
  // This method builds the query string based on the listener configuration and query modifiers.
    @TestVisible
    private static String buildQuery(
        String tableName,
        String parentIdField,
        List<Id> targetRecordIds,
        Listener__c listenerConfig,
        Boolean isHistoryQuery,
        DateTime lastExecutionOn
    ) {
        List<String> selectFields = new List<String>{'Id'};
        List<String> whereConditions = new List<String>();
        
        // Handle the fields to select and the WHERE conditions based on query type
        if (isHistoryQuery) {
            selectFields.addAll(new List<String>{'Field', 'OldValue', 'NewValue', 'CreatedDate', parentIdField});
            whereConditions.add('(Field =: fieldValue OR Field =: fieldName)');
            if (!targetRecordIds.isEmpty()) {
                whereConditions.add(parentIdField + ' IN :targetRecordIds');
            }
        } else {
            if (listenerConfig.Object_Name__c == 'Case') {
                selectFields.add('CaseNumber');
            } else {
                selectFields.add('Name');
            }
            if (listenerConfig.TerminalStage__c != null) {
                selectFields.add(listenerConfig.TerminalStage__c);
            }
            selectFields.add(listenerConfig.Field_To_Track__c);
        }

        // Get query modifiers
        Map<String, Object> queryModifiers = getQueryModifiers(isHistoryQuery, lastExecutionOn);
        if (String.isNotBlank((String)queryModifiers.get('whereClause'))) {
            whereConditions.add((String)queryModifiers.get('whereClause'));
        }
        
        // Construct the query
        String queryStr = 'SELECT ' + String.join(selectFields, ', ') + ' FROM ' + tableName;
        if (!whereConditions.isEmpty()) {
            queryStr += ' WHERE ' + String.join(whereConditions, ' AND ');
        }

        // Common query modifiers
        if ((Boolean)queryModifiers.get('includeOrderBy')) {
            queryStr += isHistoryQuery ? ' ORDER BY ' + parentIdField + ', CreatedDate ASC' : ' ORDER BY Id, CreatedDate ASC';
        }
        if ((Boolean)queryModifiers.get('includeLimit')) {
            queryStr += ' LIMIT 10000';
        }

        return queryStr;
    }
    
    @TestVisible
    private static Map<String, Object> getQueryModifiers(
        Boolean isHistoryQuery,
        DateTime lastExecutionOn
    ) {
        Map<String, Object> queryModifiers = new Map<String, Object>{
            'includeOrderBy' => true,
            'includeLimit' => true,
            'whereClause' => ''
        };
        
        if (isHistoryQuery && lastExecutionOn != null) {
            queryModifiers.put('whereClause', 'CreatedDate > :lastExecutionOn');
        }
        
        return queryModifiers;
    }


    public void sortHistoryList(List<SObject> historyList) {
      // Prepare a list of CustomDatetimeSort
      List<CustomDatetimeSort> toSort = new List<CustomDatetimeSort>();
      for(SObject record : historyList) {
        toSort.add(new CustomDatetimeSort(record));
      } 
  
      // Now sort the list with custom sorting
      toSort.sort();
  
      // Additional sorting logic based on order of creation
      Datetime previousDateTime = null;
      Integer count = 1;
      for (CustomDatetimeSort sortedRecord : toSort) {
          SObject record = sortedRecord.record;
          Datetime recordDatetime = (Datetime) record.get('CreatedDate');
          if (previousDateTime != null && recordDatetime == previousDateTime) {
              count++;
          } else {
              count = 1;
          }
          previousDateTime = recordDatetime;
      }
    }

  // /**
  //  * Fetches the latest history records for given parent records based on listener configuration and query modifiers.
  //  *
  //  * This method queries the history table corresponding to the object specified in the listener configuration.
  //  * It constructs a query based on the given parent record IDs and query modifiers. The method returns two maps:
  //  * - A map of parent record IDs to their corresponding list of history records.
  //  * - A map of parent record IDs to a sorted list of Datetimes, which helps in sorting the history records.
  //  *
  //  * @param mParent List of parent record IDs to fetch the history for.
  //  * @param listenerConfig Configuration for the listener, containing object and field names.
  //  * @param queryModifiers A map containing query modifiers like 'whereClause', 'includeOrderBy', etc.
  //  * @return HistoryValuesResult A wrapper class containing both maps.
  //  */
  @TestVisible
  private static HistoryValuesResult getLatestHistoryValues(
    List<Id> targetRecordIds,
    Listener__c listenerConfig,
    DateTime lastExecutionOn,
    ListenerFlowController controllerInstance,
    String objHistoryName,
    String parentIdField
    ) {
    controllerInstance.sortingDateTimeMap.clear();
    String fieldValue = 'created';
    String fieldName = listenerConfig.Field_To_Track__c;
    String objectSuffix = '__c';
    Boolean isHistoryQuery = true;
    String queryStr = buildQuery(objHistoryName, parentIdField, targetRecordIds, listenerConfig, true, lastExecutionOn);
    System.debug('queryStr: ' + queryStr);

    // Query for history records
    Map<Id, List<SObject>> historyRecordsMap = controllerInstance.historyRecordsMap;
    // HISTORY RECORDS QUERY to populate historyRecordsMap and sortingDateTimeMap
    for (SObject obj : Database.query(queryStr)) {
      Id parentId = (Id) obj.get(parentIdField);
      Datetime createdDate = (Datetime) obj.get('CreatedDate');

      // Populate historyRecordsMap
      if (historyRecordsMap.containsKey(parentId)) {
        historyRecordsMap.get(parentId).add(obj);
      } else {
        historyRecordsMap.put(parentId, new List<SObject>{ obj });
      }
      // Populate sortingDateTimeMap
      if (controllerInstance.sortingDateTimeMap.containsKey(parentId)) {
        controllerInstance.sortingDateTimeMap.get(parentId).add(createdDate);
      } else {
        controllerInstance.sortingDateTimeMap.put(parentId, new List<Datetime>{ createdDate });
      }
    }

    if (!historyRecordsMap.isEmpty()) {
      // Sort using sortHistoryList method
      for (Id parentId : historyRecordsMap.keySet()) {
        List<SObject> specificHistoryList = (List<SObject>) historyRecordsMap.get(parentId);
        controllerInstance.sortHistoryList(specificHistoryList);
        historyRecordsMap.put(parentId, specificHistoryList);
      }
    }
    
    // Handle the oneHistoryParentIds logic
    Set<Id> oneHistoryParentIds = new Set<Id>();
    Map<Id, SObject> createdHistoryMap = new Map<Id, SObject>();
    for (Id parentId : historyRecordsMap.keySet()) {
      List<SObject> tempHistoryLst = historyRecordsMap.get(parentId);
      if (tempHistoryLst.size() == 1) {
        oneHistoryParentIds.add(parentId);
      }
    }
    // Handle special case for parents with only one 'created' history record
    if (!oneHistoryParentIds.isEmpty()) {
      for (Id oneHistoryParentId : oneHistoryParentIds) {
        List<SObject> historyList = historyRecordsMap.get(oneHistoryParentId);
        SObject createdHistoryRecord = historyList[0]; // Only one record exists, so taking the first
        
        // Fetch the current value from the parent record map
        SObject parentRecord = controllerInstance.parentRecordsMap.get(oneHistoryParentId);
        Object currentFieldValue = parentRecord.get(fieldName);
        
        // Create a new EditableHistory instance and set its fields.
        EditableHistory editableRecord = new EditableHistory();
        editableRecord.Id = (String)createdHistoryRecord.get('Id');
        editableRecord.OldValue = (String)createdHistoryRecord.get('OldValue');
        editableRecord.NewValue = (String)currentFieldValue;
        
        // Optionally, update the historyRecordsMap
        historyRecordsMap.put(oneHistoryParentId, new List<SObject>{ createdHistoryRecord });
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

    // Return both maps in a wrapper class
    return new HistoryValuesResult(controllerInstance.historyRecordsMap, controllerInstance.sortingDateTimeMap);
  }

  // Called by: parseRecordsToFlow
  // This method takes in a listener flow record, a map of parent record ids and a list of history records for each parent record id, a map of goal step records, and a map of parent record ids and parent records.
  // It returns a response object with a list of listener flow controller objects.
  @TestVisible
  public void preparingResponse(
    ListenerFlowLatestResponse response,
    Listener__c listenerConfig,
    Map<String, SObject> sObjectMap,
    ListenerFlowController controllerInstance
  ) {
    for (Id parentRecId : controllerInstance.sortingDateTimeMap.keySet()) {
      Integer count = 0;
      if(response.lstListenerFlow == null) {
        response.lstListenerFlow = new List<ListenerFlowController>();
      }
      for (Datetime dt : controllerInstance.sortingDateTimeMap.get(parentRecId)) {
        ListenerFlowController trackFlowObj = new ListenerFlowController();
        List<SObject> listSObj = controllerInstance.historyRecordsMap.get(parentRecId);
        SObject SObj = listSObj[count];
        
        String fieldValue;
        String newValue;
        
        if (SObj.get('Field') == 'created') {
          if (listSObj.size() > 1 && listSObj.size() > count + 1 && listSObj[count + 1].get('Field') == listenerConfig.Field_To_Track__c) {
              fieldValue = String.valueOf(listSObj[count + 1].get('OldValue')); 
          } else {
              // Fetching the current value directly from the parent object
              fieldValue = String.valueOf(sObjectMap.get(parentRecId).get(listenerConfig.Field_To_Track__c));
          }
        } else {
          fieldValue = String.valueOf(SObj.get('NewValue'));
        }
        
        // Populating trackFlowObj 
        trackFlowObj.varHistoryRecordId = (Id) SObj.get('Id');
        trackFlowObj.varCurrentFieldTracked = listenerConfig.Field_To_Track__c;
        trackFlowObj.varCurrentFieldValue = fieldValue;
        trackFlowObj.varCurrentObjectID = parentRecId;
        String parentName = getParentName(listenerConfig.Object_Name__c);
        trackFlowObj.varNameofTrackedRecord = (String) sObjectMap.get(parentRecId).get(parentName);
        trackFlowObj.varTerminalStage = false; 
        trackFlowObj.varTrackedCustomObjectName = listenerConfig.Object_Name__c; 
        trackFlowObj.varEditStartTime = dt;
        trackFlowObj.varEditEndTime = null; 
        trackFlowObj.varType = listenerConfig.Type__c; 

        response.lstListenerFlow.add(trackFlowObj);
        count++;
      }
    }
    response.hasRecords = !historyRecordsMap.isEmpty();
  }

  // /**
  //  * Queries for target records and their corresponding history records, then prepares a response for the flow.
  //  *
  //  * This method serves as the main entry point for the ListenerFlowController. It performs the following steps:
  //  * 1. It fetches target records based on the listener configuration and query modifiers.
  //  * 2. It then retrieves the history records for these target records.
  //  * 3. Finally, it prepares a response object with the fetched data.stenerConfigRec
  //  *
  //  * The method uses the 'getQueryModifiers' and 'getLatestHistoryValues' utility methods for query modification
  //  * and history record retrieval, respectively. It also updates the 'Error_Message__c' field in the listener
  //  * configuration record in case of an exception.
  //  *
  //  * @param listenerConfigList List of listener configuration records.
  //  * @return List<ListenerFlowLatestResponse> A list of response objects containing the fetched data.
  //  */
  @InvocableMethod(
    label='Query & Parse History Records'
    description='Used to query History Records in Flow'
    category='ListenerFlowController'
  )
  public static List<ListenerFlowLatestResponse> parseRecordsToFlow(
  List<ListenerFlowLatestRequest> listenerConfigList) {
    // Create an instance of ListenerFlowController
    ListenerFlowController controllerInstance = new ListenerFlowController();
    Listener__c listenerConfig = listenerConfigList[0].listenerConfig;
    String objName = listenerConfig.Object_Name__c;
    // Get the history object name based on the object name in the listener config
    String objHistoryName = getHistoryObjectName(listenerConfig.Object_Name__c);
    // Get parentIdField
    String parentName = getParentName(listenerConfig.Object_Name__c);
    String parentIdField = isCustomObject(objName) ? 'ParentId' : (objName + 'Id');
    String fieldValue = 'created';
    String fieldName = listenerConfig.Field_To_Track__c;
    DateTime lastExecutionOn = listenerConfigList[0].lastExecutionOn;
    List<ListenerFlowLatestResponse> responseList = new List<ListenerFlowLatestResponse>();
    ListenerFlowLatestResponse response = new ListenerFlowLatestResponse();
    Map<Id, SObject> sObjectMapForParse = new Map<Id, SObject>();

    if (listenerConfigList.isEmpty()) {
      return responseList;
    }

    Set<Id> targetRecords = new Set<Id>();
    List<Id> targetRecordIds = new List<Id>(targetRecords);

    Map<String, SObject> sObjectMap = new Map<String, SObject>();

    Boolean isHistoryQuery = false;
    
    try {
      String terminalStageField = (listenerConfig.TerminalStage__c != null)
        ? listenerConfig.TerminalStage__c
        : '';
      String queryStr = buildQuery(objName, parentIdField, targetRecordIds, listenerConfig, isHistoryQuery, lastExecutionOn);

      if (String.isNotBlank(terminalStageField))
        queryStr += ', ' + terminalStageField;
      System.debug('queryStr: ' + queryStr);
      for (SObject sob : Database.query(queryStr)) {
        targetRecords.add(sob.Id);
        sObjectMap.put(sob.Id, sob);
      }
      for (Id recordId : sObjectMap.keySet()) {
        SObject record = sObjectMap.get(recordId);
        sObjectMapForParse.put(recordId, record);
      } 
      controllerInstance.parentRecordsMap = sObjectMapForParse;
      targetRecordIds = new List<Id>(targetRecords); 

      HistoryValuesResult historyResult = getLatestHistoryValues(
        targetRecordIds,
        listenerConfig,
        lastExecutionOn,
        controllerInstance,
        objHistoryName,
        parentIdField
      );

      Map<Id, List<SObject>> historyRecordsMap = historyResult.historyRecordsMap;
      Map<Id, List<Datetime>> sortingDateTimeMap = historyResult.sortingDateTimeMap;
      Set<Id> oneHistoryParentIds = new Set<Id>();
      for (Id parentId : historyRecordsMap.keySet()) {
        List<SObject> tempHistoryLst = historyRecordsMap.get(parentId);
        if (tempHistoryLst.size() == 1) {
          oneHistoryParentIds.add(parentId);
        }
      }

      controllerInstance.preparingResponse(response, listenerConfig, sObjectMap, controllerInstance);

      listenerConfig.Error_Message__c = '';
    } catch (Exception e) {
      response.isCheckSuccess = false;
      listenerConfig.Error_Message__c = 'Error: ' + e.getMessage() + ' Trace: ' + e.getStackTraceString();
      update listenerConfig;
    } 

    responseList.add(response);
    return responseList;
  }
}