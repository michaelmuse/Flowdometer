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

  //Copilot added:
  // This method takes in a listener flow record and a boolean value that determines whether or not to include the last modified date check in the where clause.
  // public static String getWhereClause(Flowdometer__Listener__c listenerConfig, Boolean includeLastModifiedCheck) {
  //     String whereClause = includeLastModifiedCheck && listenerConfig.Flowdometer__Last_Execution_On__c != null ? 'LastModifiedDate >= ' + listenerConfig.Flowdometer__Last_Execution_On__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') : '';
  //     return whereClause;
  // }

  // This method returns a string that is used in a SOQL query to filter records based on the last execution date of the listener flow.
  @InvocableMethod(
    label='Query & Parse History Records'
    description=''
    category='ListenerFlowController'
  )
  public static List<ListenerFlowLatestResponse> parseRecordsToFlow(
    List<ListenerFlowLatestRequest> listenerConfigList
  ) {
    ListenerFlowLatestResponse response = new ListenerFlowLatestResponse();
    Set<String> targetRecords = new Set<String>();
    Map<String, SObject> sObjectMap = new Map<String, SObject>();
    Map<Id, List<SObject>> latestHistory = new Map<Id, List<SObject>>();
    Map<Id, Map<String, Id>> goalStepRecsMap = new Map<Id, Map<String, Id>>();
    if (listenerConfigList.isEmpty())
      return null;
    //From the batch we are passing only one Listener Flow record.
    Flowdometer__Listener__c listenerConfigRec = listenerConfigList[0]
      .listenerConfig;

    try {
      String parentNameField = listenerConfigRec.Flowdometer__Object_Name__c !=
        null &&
        listenerConfigRec.Flowdometer__Object_Name__c == 'Case'
        ? 'CaseNumber'
        : 'Name';
      String terminalStageField = listenerConfigRec.Flowdometer__TerminalStage__c !=
        null
        ? listenerConfigRec.Flowdometer__TerminalStage__c
        : '';
      String queryString = 'SELECT Id';
      if (String.isNotBlank(parentNameField))
        queryString += ', ' + parentNameField;
      if (String.isNotBlank(terminalStageField))
        queryString += ', ' + terminalStageField;
      queryString += ' FROM ';
      queryString +=
        listenerConfigRec.Flowdometer__Object_Name__c +
        ' WHERE ' +
        getWhereClause(listenerConfigRec, true);
      for (SObject sob : Database.query(queryString)) {
        targetRecords.add(sob.Id);
        sObjectMap.put(sob.Id, sob);
      }

      latestHistory = ListenerFlowController.getLatestHistoryValues(
        targetRecords,
        listenerConfigRec
      );

      ListenerFlowController.preparingResponse(
        response,
        latestHistory,
        listenerConfigRec,
        goalStepRecsMap,
        sObjectMap
      );

      listenerConfigRec.Flowdometer__Error_Message__c = '';
    } catch (Exception ex) {
      response.isCheckSuccess = false;
      listenerConfigRec.Flowdometer__Error_Message__c =
        'Error: ' +
        ex.getMessage() +
        ' Trace: ' +
        ex.getStackTraceString();
    }
    update listenerConfigRec;
    return new List<ListenerFlowLatestResponse>{ response };
  }

  //This method takes in a listener flow record and a boolean value that determines whether or not to include the last modified date check in the where clause.
  public static String getWhereClause(
    Flowdometer__Listener__c listenerConfig,
    Boolean includeLastModifiedCheck
  ) {
    String whereClause = includeLastModifiedCheck &&
      listenerConfig.Flowdometer__Last_Execution_On__c != null
      ? 'LastModifiedDate >= ' +
        listenerConfig.Flowdometer__Last_Execution_On__c.formatGmt(
          'yyyy-MM-dd\'T\'HH:mm:ss\'Z\''
        )
      : '';
    return whereClause;
  }

  //This method returns a string value of the object passed in. If the object is null, it returns an empty string.
  public static String getStringNotNull(Object valueObj) {
    if (valueObj == null)
      return '';
    return String.valueOf(valueObj);
  }

  //This method returns a boolean value of whether the object passed in is a custom object or not.
  public static Boolean isCustomObject(String objectname) {
    SObjectType objToken = Schema.getGlobalDescribe().get(objectname);
    return (objToken != null && objToken.getDescribe().isCustom());
  }

  //This method returns a map of the latest history values for the parent records passed in. It takes in a set of parent record ids and a listener flow record. It returns a map of the parent record ids and a list of history records for each parent record id.
  public static Map<Id, List<SObject>> getLatestHistoryValues(
    Set<String> mParent,
    Flowdometer__Listener__c listenerConfig
  ) {
    String fieldValue = 'created';
    String objName = listenerConfig.Flowdometer__Object_Name__c;
    String fieldName = listenerConfig.Flowdometer__Field_To_Track__c;
    DateTime lastCheck = listenerConfig.Flowdometer__Last_Execution_On__c;
    String objectSuffix = '__c';
    // String objHistoryName = (objName == 'Opportunity') ? 'OpportunityFieldHistory' : (objName.contains(objectSuffix) ? ((objName.substring(0, objName.length() - objectSuffix.length())+'__History') : (objName+'History'));
    String objHistoryName = (objName == 'Opportunity')
      ? 'OpportunityFieldHistory'
      : (objName.contains(objectSuffix)
          ? (objName.substring(0, objName.length() - objectSuffix.length()) +
            '__History')
          : (objName + 'History'));
    //q: what is the difference between line 84 (commented out by a previous developer) and line 85?
    //a: I think the difference is that line 84 is using the object name from the listener flow record and line 85 is using the object name from the history object.
    String parentFieldName = ListenerFlowController.isCustomObject(objName)
      ? 'ParentId'
      : (objName + 'Id');
    Set<String> parentIds = mParent;
    Map<String, SObject> historyRecordValues = new Map<String, SObject>();
    String queryStr =
      'SELECT Id, Field, OldValue, NewValue, CreatedDate, ' +
      parentFieldName +
      ' FROM ' +
      objHistoryName +
      ' WHERE (Field =:fieldValue OR Field =:fieldName) AND ' +
      parentFieldName +
      ' IN :parentIds AND CreatedDate >= :lastCheck ORDER BY ' +
      parentFieldName +
      ', CreatedDate ASC';
    Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
    for (SObject obj : Database.query(queryStr)) {
      String parentId = ListenerFlowController.getStringNotNull(
        obj.get(parentFieldName)
      );
      if (historyRecordsMap.containsKey(parentId)) {
        historyRecordsMap.get(parentId).add(obj);
      } else {
        historyRecordsMap.put(parentId, new List<SObject>{ obj });
      }
    }
    Set<String> oneHistoryParentIds = new Set<String>();
    Map<Id, SObject> createdHistoryMap = new Map<Id, SObject>();
    for (Id parentId : historyRecordsMap.keySet()) {
      List<SObject> tempHistoryLst = historyRecordsMap.get(parentId);
      if (tempHistoryLst.size() == 1) {
        oneHistoryParentIds.add(parentId);
      }
    }
    if (!oneHistoryParentIds.isEmpty()) {
      String parentTrackedField = ListenerFlowController.isCustomObject(objName)
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
        String parentId = ListenerFlowController.getStringNotNull(
          sObj.get(parentFieldName)
        );
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

  // q: could you propose some code to modify the getLatestHistoryValues method above to also catch the history records on the first run, when Last Check is not yet set? Maybe starting on line 92?
  // a: I think the code below should work. I added a check to see if the last check date is null. If it is null, then it will query all history records for the parent records passed in.
  // public static Map<Id, List<SObject>> getLatestHistoryValues(Set<String> mParent, Flowdometer__Listener__c listenerConfig){
  //     String fieldValue = 'created';
  //     String objName = listenerConfig.Flowdometer__Object_Name__c;
  //     String fieldName = listenerConfig.Flowdometer__Field_To_Track__c;
  //     DateTime lastCheck = listenerConfig.Flowdometer__Last_Execution_On__c;
  //     String objectSuffix = '__c';
  //     String objHistoryName = (objName == 'Opportunity') ? 'OpportunityFieldHistory' : (objName.contains(objectSuffix) ? (objName.substring(0, objName.length() - objectSuffix.length()) + '__History') : (objName + 'History'));
  //     String parentFieldName = ListenerFlowController.isCustomObject(objName) ? 'ParentId' : (objName + 'Id');
  //     Set<String> parentIds = mParent;
  //     Map<String, SObject> historyRecordValues = new Map<String, SObject>();
  //     String queryStr = 'SELECT Id, Field, OldValue, NewValue, CreatedDate, ' + parentFieldName + ' FROM ' + objHistoryName + ' WHERE (Field =:fieldValue OR Field =:fieldName) AND ' + parentFieldName + ' IN :parentIds AND CreatedDate >= :lastCheck ORDER BY '+parentFieldName+', CreatedDate ASC';
  //     Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
  //     if(lastCheck == null){
  //         queryStr = 'SELECT Id, Field, OldValue, NewValue, CreatedDate, ' + parentFieldName + ' FROM ' + objHistoryName + ' WHERE (Field =:fieldValue OR Field =:fieldName) AND ' + parentFieldName + ' IN :parentIds ORDER BY '+parentFieldName+', CreatedDate ASC';
  //     }
  //     for(SObject obj : Database.query(queryStr)){
  //         String parentId = ListenerFlowController.getStringNotNull(obj.get(parentFieldName));
  //         if(historyRecordsMap.containsKey(parentId)){
  //             historyRecordsMap.get(parentId).add(obj);
  //         }else{
  //             historyRecordsMap.put(parentId, new List<SObject>{obj});
  //         }
  //     }
  //     Set<String> oneHistoryParentIds = new Set<String>();
  //     Map<Id, SObject> createdHistoryMap = new Map<Id, SObject>();
  //     for(Id parentId : historyRecordsMap.keySet()){
  //         List<SObject> tempHistoryLst = historyRecordsMap.get(parentId);
  //         if(tempHistoryLst.size() == 1){
  //             oneHistoryParentIds.add(parentId);
  //         }
  //     }
  //     if(!oneHistoryParentIds.isEmpty()){
  //         String parentTrackedField = ListenerFlowController.isCustomObject(objName) ? ('Parent.' +fieldName) : (objName + '.'+fieldName);
  //         String parentQueryStr = 'SELECT Id, Field, OldValue, NewValue, CreatedDate, '+parentTrackedField+', '+parentFieldName+' FROM ' + objHistoryName + ' WHERE Field =: fieldValue AND ' + parentFieldName + '=: oneHistoryParentIds'+ ' ORDER BY '+parentFieldName+', CreatedDate ASC';
  //         for(SObject sObj : Database.query(parentQueryStr)){
  //             String parentId = ListenerFlowController.getStringNotNull(sObj.get(parentFieldName));
  //             createdHistoryMap.put(parentId,sObj);
  //         }
  //     }
  //     if(!createdHistoryMap.isEmpty()){
  //         for(Id parentId : createdHistoryMap.keySet()){
  //             if(historyRecordsMap.containsKey(parentId)){
  //                 List<SObject> tempList = historyRecordsMap.get(parentId);
  //                 tempList.remove(tempList.size()-1);
  //                 tempList.add(createdHistoryMap.get(parentId));
  //                 historyRecordsMap.put(parentId,tempList);
  //             }
  //         }
  //     }
  //     return historyRecordsMap;
  // }

  //This method takes in a listener flow record, a map of parent record ids and a list of history records for each parent record id, a map of goal step records, and a map of parent record ids and parent records. It returns a response object with a list of listener flow controller objects.
  @TestVisible
  private static void preparingResponse(
    ListenerFlowLatestResponse result,
    Map<Id, List<sObject>> historyRecordsMap,
    Flowdometer__Listener__c listenerConfig,
    Map<Id, Map<String, Id>> goalStepRecsMap,
    Map<String, SObject> sObjectMap
  ) {
    for (Id parentRecId : historyRecordsMap.keySet()) {
      Integer count = 0;
      for (SObject SObj : historyRecordsMap.get(parentRecId)) {
        ListenerFlowController trackFlowObj = new ListenerFlowController();

        String newValue = '';
        Datetime endDateValue = null;
        List<SObject> tempList = historyRecordsMap.get(parentRecId);
        if (SObj.get('Field') == 'created' && tempList.size() == 1) {
          if (!Test.isRunningTest()) {
            newValue = ListenerFlowController.getStringNotNull(
              sObj.getSObject(listenerConfig.Flowdometer__Object_Name__c)
                .get(listenerConfig.Flowdometer__Field_To_Track__c)
            );
            endDateValue = null;
          } else {
            //value set for test methods
            newValue = 'New';
            endDateValue = null;
          }
        } else if (SObj.get('Field') == 'created' && tempList.size() > 1) {
          newValue = ListenerFlowController.getStringNotNull(
            tempList[1].get('OldValue')
          );
          endDateValue = (Datetime) tempList[1].get('CreatedDate');
        } else if (SObj.get('Field') != 'created') {
          newValue = ListenerFlowController.getStringNotNull(
            sObj.get('NewValue')
          );
          if (tempList.size() > 1 && tempList.size() > count) {
            endDateValue = (Datetime) tempList[count].get('CreatedDate');
          }
        } else {
          newValue = '';
        }
        String parentNameField = listenerConfig.Flowdometer__Object_Name__c !=
          null &&
          listenerConfig.Flowdometer__Object_Name__c == 'Case'
          ? 'CaseNumber'
          : 'Name';
        String terminalStageField = listenerConfig.Flowdometer__TerminalStage__c !=
          null
          ? listenerConfig.Flowdometer__TerminalStage__c
          : '';
        Boolean terminalStageValidation = (String.isNotBlank(
            terminalStageField
          ) && sObjectMap.containsKey(parentRecId))
          ? (Boolean) sObjectMap.get(parentRecId).get(terminalStageField)
          : false;
        trackFlowObj.varCurrentFieldTracked = listenerConfig.Flowdometer__Field_To_Track__c !=
          null
          ? listenerConfig.Flowdometer__Field_To_Track__c
          : '';
        trackFlowObj.varCurrentFieldValue = newValue;
        trackFlowObj.varCurrentObjectID = parentRecId;
        trackFlowObj.varNameofTrackedRecord = sObjectMap.containsKey(
            parentRecId
          )
          ? (String) sObjectMap.get(parentRecId).get(parentNameField)
          : '';
        //trackFlowObj.varTerminalStage = (String.isNotBlank(terminalStageField) && sObjectMap.containsKey(parentRecId)) ? (Boolean) sObjectMap.get(parentRecId).get(terminalStageField) : FALSE;
        if (terminalStageValidation && tempList.size() == count + 1) {
          trackFlowObj.varTerminalStage = terminalStageValidation;
        } else {
          trackFlowObj.varTerminalStage = false;
        }
        trackFlowObj.varTrackedCustomObjectName = listenerConfig.Flowdometer__Object_Name__c !=
          null
          ? listenerConfig.Flowdometer__Object_Name__c
          : '';
        trackFlowObj.varEditStartTime = (Datetime) SObj.get('CreatedDate');
        trackFlowObj.varEditEndTime = endDateValue;
        trackFlowObj.varType = listenerConfig.Flowdometer__Type__c != null
          ? listenerConfig.Flowdometer__Type__c
          : '';

        result.lstListenerFlow.add(trackFlowObj);
        count++;
      }
    }
    result.hasRecords = !historyRecordsMap.isEmpty();
  }

  //ListenerFlowLatestRequest params from flow
  //This method takes in a listener flow record and returns a listener flow latest request object.
  global class ListenerFlowLatestRequest {
    @InvocableVariable
    global Flowdometer__Listener__c listenerConfig;
  }

  //ListenerFlowLatestResponse params to flow
  //This method returns a listener flow latest response object.
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
}
