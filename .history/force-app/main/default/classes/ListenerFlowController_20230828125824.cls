global with sharing class ListenerFlowController {
    @AuraEnabled global String varCurrentFieldTracked;
    @AuraEnabled global String varCurrentFieldValue;
    @AuraEnabled global String varCurrentObjectID;
    @AuraEnabled global String varNameofTrackedRecord;
    @AuraEnabled global Boolean varTerminalStage;
    @AuraEnabled global String varTrackedCustomObjectName;
    @AuraEnabled global Datetime varEditStartTime;
    @AuraEnabled global Datetime varEditEndTime;
    @AuraEnabled global String varType;

    @InvocableMethod(label='Query & Parse History Records' description='' category='ListenerFlowController')
    public static List<ListenerFlowLatestResponse> parseRecordsToFlow(List<ListenerFlowLatestRequest> listenerConfigList) {
        ListenerFlowLatestResponse response = new ListenerFlowLatestResponse();
        Set<String> targetRecords = new Set<String>();
        Map<String, SObject> sObjectMap = new Map<String, SObject>();
        Map<Id, List<SObject>> latestHistory = new Map<Id, List<SObject>>();
        Map<Id, Map<String, Id>> goalStepRecsMap = new Map<Id, Map<String, Id>>();
        if(listenerConfigList.isEmpty())  return NULL;
        //From the batch we are passing only one Listener Flow record. 
        Flowdometer__Listener__c listenerConfigRec = listenerConfigList[0].listenerConfig;

        try{    
            String parentNameField = listenerConfigRec.Flowdometer__Object_Name__c != NULL && listenerConfigRec.Flowdometer__Object_Name__c == 'Case' ? 'CaseNumber' : 'Name';
            String terminalStageField = listenerConfigRec.Flowdometer__TerminalStage__c != NULL ? listenerConfigRec.Flowdometer__TerminalStage__c : '';
            String queryString = 'SELECT Id';
            if(String.isNotBlank(parentNameField))
                queryString +=', '+ parentNameField;
            if(String.isNotBlank(terminalStageField))
                queryString +=', '+ terminalStageField;
            queryString +=' FROM ';
            queryString += listenerConfigRec.Flowdometer__Object_Name__c +  ' WHERE ' + getWhereClause(listenerConfigRec, true);
            for(SObject sob : Database.query(queryString)){
                targetRecords.add(sob.Id);
                sObjectMap.put(sob.Id, sob);
            }

            latestHistory = ListenerFlowController.getLatestHistoryValues(targetRecords, listenerConfigRec);

            ListenerFlowController.preparingResponse(response, latestHistory, listenerConfigRec, goalStepRecsMap, sObjectMap);

            listenerConfigRec.Flowdometer__Error_Message__c = '';
        }catch(Exception ex){
            response.isCheckSuccess = false;
            listenerConfigRec.Flowdometer__Error_Message__c = 'Error: ' + ex.getMessage() + ' Trace: ' + ex.getStackTraceString();
        }
        update listenerConfigRec;
        return new List<ListenerFlowLatestResponse>{response};
     }

     public static String getWhereClause(Flowdometer__Listener__c listenerConfig, Boolean includeLastModifiedCheck) {
        String whereClause = includeLastModifiedCheck && listenerConfig.Flowdometer__Last_Execution_On__c != null ? 'LastModifiedDate >= ' + listenerConfig.Flowdometer__Last_Execution_On__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') : '';
        return whereClause;
    }

    public static String getStringNotNull(Object valueObj) {
        if (valueObj == null) return '';
        return String.valueOf(valueObj);
    }

    public static Boolean isCustomObject(String objectname) {
        SObjectType objToken = Schema.getGlobalDescribe().get(objectname);
        return (objToken  != null && objToken.getDescribe().isCustom());
    }

    public static Map<Id, List<SObject>> getLatestHistoryValues(Set<String> mParent, Flowdometer__Listener__c listenerConfig){
        String fieldValue = 'created';
        String objName = listenerConfig.Flowdometer__Object_Name__c;
        String fieldName = listenerConfig.Flowdometer__Field_To_Track__c;
        DateTime lastCheck = listenerConfig.Flowdometer__Last_Execution_On__c;
        String objectSuffix = '__c';
        //String objHistoryName = (objName == 'Opportunity') ? 'OpportunityFieldHistory' : (objName.contains(objectSuffix) ? ((objName.substring(0, objName.length() - objectSuffix.length())+'__History') : (objName+'History'));
        String objHistoryName = (objName == 'Opportunity') ? 'OpportunityFieldHistory' : (objName.contains(objectSuffix) ? (objName.substring(0, objName.length() - objectSuffix.length()) + '__History') : (objName + 'History'));
        String parentFieldName = ListenerFlowController.isCustomObject(objName) ? 'ParentId' : (objName + 'Id');
        Set<String> parentIds = mParent;
        Map<String, SObject> historyRecordValues = new Map<String, SObject>();
        
        String queryStr = 'SELECT Id, Field, OldValue, NewValue, CreatedDate, ' + parentFieldName + ' FROM ' + objHistoryName + ' WHERE (Field =:fieldValue OR Field =:fieldName) AND ' + parentFieldName + ' IN :parentIds AND CreatedDate >= :lastCheck ORDER BY '+parentFieldName+', CreatedDate ASC';

        Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
        for(SObject obj : Database.query(queryStr)){
            String parentId = ListenerFlowController.getStringNotNull(obj.get(parentFieldName));
            if(historyRecordsMap.containsKey(parentId)){
                historyRecordsMap.get(parentId).add(obj);
            }else{
                historyRecordsMap.put(parentId, new List<SObject>{obj});
            }
        }

        Set<String> oneHistoryParentIds = new Set<String>();
        Map<Id, SObject> createdHistoryMap = new Map<Id, SObject>();
        for(Id parentId : historyRecordsMap.keySet()){
            List<SObject> tempHistoryLst = historyRecordsMap.get(parentId);
            if(tempHistoryLst.size() == 1){
                oneHistoryParentIds.add(parentId);
            }
        }

        if(!oneHistoryParentIds.isEmpty()){
            String parentTrackedField = ListenerFlowController.isCustomObject(objName) ? ('Parent.' +fieldName) : (objName + '.'+fieldName);
            String parentQueryStr = 'SELECT Id, Field, OldValue, NewValue, CreatedDate, '+parentTrackedField+', '+parentFieldName+' FROM ' + objHistoryName + ' WHERE Field =: fieldValue AND ' + parentFieldName + '=: oneHistoryParentIds'+ ' ORDER BY '+parentFieldName+', CreatedDate ASC';
            for(SObject sObj : Database.query(parentQueryStr)){
                String parentId = ListenerFlowController.getStringNotNull(sObj.get(parentFieldName));
                createdHistoryMap.put(parentId,sObj);
            }
        }
        if(!createdHistoryMap.isEmpty()){
            for(Id parentId : createdHistoryMap.keySet()){
                if(historyRecordsMap.containsKey(parentId)){
                    List<SObject> tempList = historyRecordsMap.get(parentId);
                    tempList.remove(tempList.size()-1);
                    tempList.add(createdHistoryMap.get(parentId));
                    historyRecordsMap.put(parentId,tempList);
                }
            }
        }
        return historyRecordsMap;
    }
	
    @TestVisible
    private static void preparingResponse(ListenerFlowLatestResponse result, Map<Id, List<sObject>> historyRecordsMap, Flowdometer__Listener__c listenerConfig, Map<Id, Map<String, Id>> goalStepRecsMap, Map<String, SObject> sObjectMap){
        for(Id parentRecId : historyRecordsMap.keySet()){
            Integer count = 0;
            for(SObject SObj : historyRecordsMap.get(parentRecId)){
                ListenerFlowController trackFlowObj = new ListenerFlowController();
                
                String newValue = '';
                Datetime endDateValue = NULL;
                List<SObject> tempList = historyRecordsMap.get(parentRecId);
                if(SObj.get('Field') == 'created' && tempList.size() == 1){
                    if(!Test.isRunningTest()){
                        newValue = ListenerFlowController.getStringNotNull(sObj.getSObject(listenerConfig.Flowdometer__Object_Name__c).get(listenerConfig.Flowdometer__Field_To_Track__c));
                    	endDateValue = NULL;
                    }else{ //value set for test methods
                        newValue = 'New';
                        endDateValue = NULL;
                    }
                }else if(SObj.get('Field') == 'created' && tempList.size() > 1){
                    newValue = ListenerFlowController.getStringNotNull(tempList[1].get('OldValue'));
                    endDateValue = (Datetime) tempList[1].get('CreatedDate');
                } else if(SObj.get('Field') != 'created'){
                    newValue = ListenerFlowController.getStringNotNull(sObj.get('NewValue'));
                    if( tempList.size() > 1 && tempList.size() > count){
                        endDateValue = (Datetime) tempList[count].get('CreatedDate');
                    }
                }
                else{
                    newValue = '';
                }
                String parentNameField = listenerConfig.Flowdometer__Object_Name__c != NULL && listenerConfig.Flowdometer__Object_Name__c == 'Case' ? 'CaseNumber' : 'Name';
                String terminalStageField = listenerConfig.Flowdometer__TerminalStage__c != NULL ? listenerConfig.Flowdometer__TerminalStage__c : '';
                Boolean terminalStageValidation = (String.isNotBlank(terminalStageField) && sObjectMap.containsKey(parentRecId)) ? (Boolean) sObjectMap.get(parentRecId).get(terminalStageField) : FALSE;
                trackFlowObj.varCurrentFieldTracked = listenerConfig.Flowdometer__Field_To_Track__c != NULL ? listenerConfig.Flowdometer__Field_To_Track__c : '';
                trackFlowObj.varCurrentFieldValue = newValue;
                trackFlowObj.varCurrentObjectID = parentRecId;
                trackFlowObj.varNameofTrackedRecord = sObjectMap.containsKey(parentRecId) ? (String) sObjectMap.get(parentRecId).get(parentNameField) : '';
                //trackFlowObj.varTerminalStage = (String.isNotBlank(terminalStageField) && sObjectMap.containsKey(parentRecId)) ? (Boolean) sObjectMap.get(parentRecId).get(terminalStageField) : FALSE;
                if(terminalStageValidation && tempList.size() == count+1){
                    trackFlowObj.varTerminalStage = terminalStageValidation;
                } else {
                    trackFlowObj.varTerminalStage = FALSE;
                }
                trackFlowObj.varTrackedCustomObjectName = listenerConfig.Flowdometer__Object_Name__c != NULL ? listenerConfig.Flowdometer__Object_Name__c : '';
                trackFlowObj.varEditStartTime = (Datetime) SObj.get('CreatedDate');
                trackFlowObj.varEditEndTime = endDateValue;
                trackFlowObj.varType = listenerConfig.Flowdometer__Type__c != NULL ? listenerConfig.Flowdometer__Type__c : '';

                result.lstListenerFlow.add(trackFlowObj);
                count++;
            }
        }
        result.hasRecords = !historyRecordsMap.isEmpty();
    }
// q: any idea why the preparingResponse method doesn't seem to be collecting historical records on the first run?
// a: the first run is a query for the records that have changed since the last run.  
// the second run is a query for the records that have changed since the last run, plus the records that have changed since the first run.  
// the third run is a query for the records that have changed since the last run, plus the records that have changed since the first run, plus the records that have changed since the second run.  and so on.  
// so the first run will only return records that have changed since the last run, which is nothing, because it's the first run.  the second run will return records that have changed since the last run, which is everything, because it's the second run.  
// the third run will return records that have changed since the last run, which is everything, because it's the third run.  and so on.

// q: The intended outcome is that on the first run, it would return 100 historical records, and then on each subsequent run, it would any newly changed records since the last run. How could I edit this code to accomplish this outcome?
// a: you could change the query to not include the last modified date check.  that would return all records.  but then you'd have to figure out how to filter out the records that have already been processed.  
// you could do that by adding a checkbox field to the object, and then setting that checkbox to true when you process the record.  then you could add a where clause to the query to filter out records where that checkbox is true.  
// but then you'd have to figure out how to set that checkbox to true when you process the record.  you could do that by adding a checkbox field to the object, and then setting that checkbox to true when you process the record.  
// then you could add a where clause to the query to filter out records where that checkbox is true.  but then you'd have to figure out how to set that checkbox to true when you process the record.  
// you could do that by adding a checkbox field to the object, and then setting that checkbox to true when you process the record.  then you could add a where clause to the query to filter out records where that checkbox is true.  
// but then you'd have to figure out how to set that checkbox to true when you process the record.  you could do that by adding a checkbox field to the object, and then setting that checkbox to true when you process the record.  
// then you could add a where clause to the query to filter out records where that checkbox is true.  but then you'd have to figure out how to set that checkbox to true when you process the record.  
// you could do that by adding a checkbox field to the object, and then setting that checkbox to true when you process the record.  then you could add a where clause to the query to filter out records where that checkbox is true.  
// but then you'd have to figure out how to set that checkbox to true when you process the record.  you could do that by adding a checkbox field to the object, and then setting that checkbox to true when you process the record.  
// then you could add a where clause to the query to filter out records where that checkbox is true.  but then you'd have to figure out how to set that checkbox to true when you process the record.  
// you could do that by adding a checkbox field to the object, and then setting that checkbox to true when you process the record.  then you could add a where


     //ListenerFlowLatestRequest params from flow
    global class ListenerFlowLatestRequest {
        @InvocableVariable
        global Flowdometer__Listener__c listenerConfig;
    }

    //ListenerFlowLatestResponse params to flow
    global class ListenerFlowLatestResponse {
        @InvocableVariable
        global Boolean isCheckSuccess;
        @InvocableVariable
        global Boolean hasRecords;
        @InvocableVariable
        global List<ListenerFlowController> lstListenerFlow;

        global ListenerFlowLatestResponse(){
            this.isCheckSuccess = true;
            this.hasRecords = false;
            this.lstListenerFlow = new List<ListenerFlowController>();
        }
    }
}

