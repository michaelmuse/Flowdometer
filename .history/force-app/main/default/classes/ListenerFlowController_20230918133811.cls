// Class: ListenerFlowController
// Path: force-app\main\default\classes\ListenerFlowController.cls

// Purpose: Manages Salesforce object history tracking for specified objects and fields based on Listener__c custom object configurations.
// Functionality Overview:
// - Uses Listener__c custom object to define object and field to track.
// - Dynamically constructs SOQL queries based on Listener__c settings and additional query modifiers.
// - Queries the main object to get target records, then queries corresponding history records.
// - Sorts history records based on CreatedDate.
// - Populates and returns a list of ListenerFlowLatestResponse objects, each containing related history data.
//
// How it Works:
// 1. Takes a list of ListenerFlowLatestRequest objects, each containing a Listener__c configuration.
// 2. Based on Listener__c settings, constructs query to fetch target records.
//    - Utilizes 'getQueryModifiers' to dynamically modify the query.
// 3. Queries history records for fetched target records.
//    - Utilizes 'getLatestHistoryValues' to perform this query.
// 4. Processes the fetched history records and target records.
//    - Utilizes 'preparingResponse' to populate ListenerFlowLatestResponse objects.
//
// Exception Handling:
// - Catches any exceptions during execution, updates 'Error_Message__c' field on Listener__c and sets 'isCheckSuccess' to false in the response.
// Note: Optionally includes terminal stage and parent name fields in the query if specified in Listener__c.
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
  @AuraEnabled
  global String varCurrentFieldTracked;
  @AuraEnabled
  global String varCurrentFieldValue;
  @AuraEnabled
  global String varCurrentObjectID;
  @AuraEnabled
  public Map<Id, List<SObject>> historyRecordsMap;
  public Map<Id, List<Datetime>> sortingDateTimeMap;
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

  // Called by: getLatestHistoryValues
  // Comparator Class for Date sorting by milliseconds
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

  // Define the ListenerFlowLatestRequest class only once
  global class ListenerFlowLatestRequest {
    @InvocableVariable
    global Listener__c listenerConfig;

    @InvocableVariable
    global DateTime lastExecutionOn;
  }

  // Define the listenerConfigList variable
  public static List<ListenerFlowLatestRequest> listenerConfigList;
  
  private static String buildQuery(
    String objHistoryName,
    String parentFieldName,
    String fieldValue,
    String fieldName,
    List<Id> mParent,
    Map<String, Object> queryModifiers
  ) {
    String queryStr = 'SELECT Id, Field, OldValue, NewValue, CreatedDate, ' + parentFieldName +
      ' FROM ' + objHistoryName +
      ' WHERE (Field =:fieldValue OR Field =:fieldName) AND ' +
      parentFieldName + ' IN :mParent';
  
    String whereClause = (String) queryModifiers.get('whereClause');
    if (whereClause != null && whereClause != '') {
      queryStr += ' AND ' + whereClause;
    }
  
    if ((Boolean) queryModifiers.get('includeOrderBy')) {
      queryStr += ' ORDER BY ' + parentFieldName + ', CreatedDate ASC';
    }
  
    if ((Boolean) queryModifiers.get('includeLimit')) {
      queryStr += ' LIMIT 10000';
    }
  
    return queryStr;
  }
    // Called by: getLatestHistoryValues
    // This method returns a map of query modifiers based on the listener configuration and other parameters
    @TestVisible
    private static Map<String, Object> getQueryModifiers(
        Listener__c listenerConfig,
        Boolean isHistoryQuery,
        DateTime lastExecutionOn
    ) {
        Map<String, Object> queryModifiers = new Map<String, Object>();
        queryModifiers.put('includeOrderBy', true); // Always include ORDER BY
        queryModifiers.put('includeLimit', true);   // Always include LIMIT

        // Generate the whereClause
        String whereClause = '';  
        if (isHistoryQuery && lastExecutionOn != null) {
            whereClause += ' AND CreatedDate > :lastExecutionOn';
        }
        queryModifiers.put('whereClause', whereClause);

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
              // record.put('Order_of_Creation__c', count); 
          } else {
              count = 1;
              // record.put('Order_of_Creation__c', count);
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
    List<Id> mParent,
    Listener__c listenerConfig,
    Map<String, Object> queryModifiers,
    DateTime lastExecutionOn,
    ListenerFlowController controllerInstance
  ) {
    controllerInstance.sortingDateTimeMap.clear();
    String fieldValue = 'created';
    String objName = listenerConfig.Object_Name__c;
    String fieldName = listenerConfig.Field_To_Track__c;
    String objectSuffix = '__c';
    String objHistoryName = getHistoryObjectName(objName);
    String parentFieldName = isCustomObject(objName)
      ? 'ParentId'
      : (objName + 'Id');

    // Generate query modifiers for history
    Map<String, Object> historyQueryModifiers = getQueryModifiers(
        listenerConfig,
        true,
        lastExecutionOn  // pass along the new parameter
    );
    String queryStr = buildQuery(objHistoryName, parentFieldName, fieldValue, fieldName, mParent, historyQueryModifiers);

    // Debug for queryStr
    System.debug('Executing history query: ' + queryStr);
    Map<Id, List<SObject>> historyRecordsMap = controllerInstance.historyRecordsMap;
    // Populate historyRecordsMap and sortingDateTimeMap
    for (SObject obj : Database.query(queryStr)) {
      Id parentId = (Id) obj.get(parentFieldName);
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
      // Create an instance of ListenerFlowController
      ListenerFlowController controller = new ListenerFlowController();

      // Sort using your sortHistoryList method
      for (Id parentId : historyRecordsMap.keySet()) {
        List<SObject> specificHistoryList = (List<SObject>) historyRecordsMap.get(parentId);
        controller.sortHistoryList(specificHistoryList);
        historyRecordsMap.put(parentId, specificHistoryList);
      }
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
        Id parentId = (Id) sObj.get(parentFieldName);
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

    // Return both maps in a wrapper class
    return new HistoryValuesResult(historyRecordsMap, sortingDateTimeMap);
  }

  // Called by: parseRecordsToFlow
  // This method takes in a listener flow record, a map of parent record ids and a list of history records for each parent record id, a map of goal step records, and a map of parent record ids and parent records.
  // It returns a response object with a list of listener flow controller objects.
  @TestVisible
  public static void preparingResponse(
    ListenerFlowLatestResponse response,
    Map<Id, List<SObject>> historyRecordsMap,
    Listener__c listenerConfig,
    Map<String, SObject> sObjectMap,
    Map<Id, List<Datetime>> sortingDateTimeMap
  ) {
    System.debug('Entering preparingResponse with historyRecordsMap: ' + historyRecordsMap);
    for (Id parentRecId : sortingDateTimeMap.keySet()) {
      System.debug('Inside loop with parentRecId: ' + parentRecId);
      Integer count = 0;
      // loop
      if(response.lstListenerFlow == null) {
        response.lstListenerFlow = new List<ListenerFlowController>();
      }
      for (Datetime dt : sortingDateTimeMap.get(parentRecId)) {
        ListenerFlowController trackFlowObj = new ListenerFlowController();
        System.debug('State of trackFlowObj: ' + trackFlowObj);
        SObject SObj = historyRecordsMap.get(parentRecId)[count];
        
        // Populating trackFlowObj based on old logic
        trackFlowObj.varHistoryRecordId = (Id) SObj.get('Id');
        trackFlowObj.varCurrentFieldTracked = listenerConfig.Field_To_Track__c;
        trackFlowObj.varCurrentFieldValue = String.valueOf(SObj.get('NewValue')); // Assuming NewValue is the field you're interested in
        trackFlowObj.varCurrentObjectID = parentRecId;
        trackFlowObj.varNameofTrackedRecord = (String) sObjectMap.get(parentRecId).get('Name'); // Assuming 'Name' is the field you're interested in
        trackFlowObj.varTerminalStage = false; // You can set this based on your business logic
        trackFlowObj.varTrackedCustomObjectName = listenerConfig.Object_Name__c; // Assuming Object_Name__c is the field you're interested in
        trackFlowObj.varEditStartTime = dt;
        trackFlowObj.varEditEndTime = null; // You can set this based on your business logic
        trackFlowObj.varType = listenerConfig.Type__c; // Assuming Type__c is the field you're interested in

        System.debug('trackFlowObj.varHistoryRecordId: ' + trackFlowObj.varHistoryRecordId);
        System.debug('trackFlowObj.varCurrentFieldTracked: ' + trackFlowObj.varCurrentFieldTracked);
        
        response.lstListenerFlow.add(trackFlowObj);
        System.debug('State of response.lstListenerFlow inside loop: ' + response.lstListenerFlow);
        count++;
      }
    }
    System.debug('Exiting preparingResponse with historyRecordsMap: ' + historyRecordsMap);
    response.hasRecords = !historyRecordsMap.isEmpty();
  }

  // /**
  //  * Queries for target records and their corresponding history records, then prepares a response for the flow.
  //  *
  //  * This method serves as the main entry point for the ListenerFlowController. It performs the following steps:
  //  * 1. It fetches target records based on the listener configuration and query modifiers.
  //  * 2. It then retrieves the history records for these target records.
  //  * 3. Finally, it prepares a response object with the fetched data.
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
    System.debug('parseRecordsToFlow called');
    Listener__c listenerConfigRec = listenerConfigList[0].listenerConfig;
    DateTime lastExecutionOn = listenerConfigList[0].lastExecutionOn;
    List<ListenerFlowLatestResponse> responseList = new List<ListenerFlowLatestResponse>();
    ListenerFlowLatestResponse response = new ListenerFlowLatestResponse();

    // Debug for initial conditions
    System.debug('Initial listenerConfigList: ' + listenerConfigList);

    if (listenerConfigList.isEmpty()) {
      return responseList;
    }

    Set<Id> targetRecords = new Set<Id>(); // Initialized here
    List<Id> targetRecordIds;

    Map<String, SObject> sObjectMap = new Map<String, SObject>();

    // Debug for listenerConfigRec
    System.debug('listenerConfigRec: ' + listenerConfigRec);

    Map<String, Object> queryModifiers = getQueryModifiers(
        listenerConfigRec,
        false,
        lastExecutionOn
    );

    // Debug for queryModifiers
    System.debug('queryModifiers: ' + queryModifiers);

    try {
      String parentNameField = (listenerConfigRec.Object_Name__c != null &&
        listenerConfigRec.Object_Name__c == 'Case')
        ? 'CaseNumber'
        : 'Name';
      String terminalStageField = (listenerConfigRec.TerminalStage__c != null)
        ? listenerConfigRec.TerminalStage__c
        : '';
      String queryString = 'SELECT Id';

      if (String.isNotBlank(parentNameField))
        queryString += ', ' + parentNameField;
      if (String.isNotBlank(terminalStageField))
        queryString += ', ' + terminalStageField;

      // Build the initial part of the queryString
      queryString += ' FROM ' + listenerConfigRec.Object_Name__c;

      // Retrieve whereClause from queryModifiers
      String whereClause = (String) queryModifiers.get('whereClause');

      // Debug log to check whereClause
      System.debug('whereClause: ' + whereClause);

      // Check if whereClause is not empty before appending
      if (String.isNotBlank(whereClause)) {
          queryString += ' WHERE ' + whereClause;
      }

      // Debug for queryString
      System.debug('Executing query: ' + queryString);
      for (SObject sob : Database.query(queryString)) {
        targetRecords.add(sob.Id);
        sObjectMap.put(sob.Id, sob);
      }
      // Debug for queryString
      System.debug('Executing query: ' + queryString);

      targetRecordIds = new List<Id>(targetRecords); 
      // Debug for targetRecordIds
      System.debug('targetRecordIds: ' + targetRecordIds);

      HistoryValuesResult historyResult = getLatestHistoryValues(
        targetRecordIds,
        listenerConfigRec,
        queryModifiers,
        lastExecutionOn 
      );
      System.debug('historyResult: ' + historyResult);
      Map<Id, List<SObject>> historyRecordsMap = historyResult.historyRecordsMap;
      Map<Id, List<Datetime>> sortingDateTimeMap = historyResult.sortingDateTimeMap;
      System.debug('History Records Map: ' + historyRecordsMap);

      preparingResponse(
        response,
        historyRecordsMap,
        listenerConfigRec,
        sObjectMap,
        sortingDateTimeMap
      );
      System.debug('State of response.lstListenerFlow: ' + response.lstListenerFlow);
      listenerConfigRec.Error_Message__c = '';
    } catch (Exception e) {
      response.isCheckSuccess = false;
      listenerConfigRec.Error_Message__c =
        'Error: ' +
        e.getMessage() +
        ' Trace: ' +
        e.getStackTraceString();
      // Debug for exception
      System.debug('Exception caught: ' + e);
      update listenerConfigRec;
      responseList.add(response);
    }
    System.debug('Return value from parseRecordsToFlow: ' + responseList);
    return responseList;
  }
}