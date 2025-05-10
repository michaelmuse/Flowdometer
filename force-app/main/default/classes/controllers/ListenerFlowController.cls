// Main controller class for Flowdometer's history tracking functionality
// Handles querying, processing, and batching of history records
global with sharing class ListenerFlowController {
    //This is a managed package, so we need global modifiers
    @AuraEnabled
    global String varCurrentFieldTracked;
    @AuraEnabled
    global String varCurrentFieldValue;
    @AuraEnabled
    global String varCurrentObjectID;
    @AuraEnabled
    public Map<Id, List<SObject>> historyRecordsMap;
    public Map<Id, List<Datetime>> sortingDatetimeMap;
    public Map<Id, SObject> parentRecordsMap = new Map<Id, SObject>();
    @AuraEnabled
    global String varNameofTrackedRecord;
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
    @AuraEnabled
    global Id varLastHistoryRecordId;
    public List<ListenerFlowController> processedRecords = new List<ListenerFlowController>();
    private static List<Id> historyRecordIdsToExclude;
    
    // Retry tracking system to prevent infinite loops and handle transient errors
    private static Map<Id, Integer> retryCountMap = new Map<Id, Integer>();
    private static Integer MAX_RETRY_COUNT = 3; // Maximum retries per listener before giving up
    
    // Inner class for ListenerFlowLatestResponse parameter setting on Flow record
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
    
    // Simplified version of ListenerFlowController for JSON serialization
    // Used to reduce payload size when storing unprocessed records
    public class SimplifiedListenerFlowController {
        public Id varHistoryRecordId;
        public String varCurrentFieldTracked;
        public String varCurrentFieldValue;
        public Id varCurrentObjectID;
        public String varNameofTrackedRecord;
        public String varTrackedCustomObjectName;
        public Datetime varEditStartTime;
        public Datetime varEditEndTime;
        public Id varLastHistoryRecordId;
        public String varType;
    }

    // Custom exception class for validation errors
    public class CustomException extends Exception {}
    
    //Constructor class
    public ListenerFlowController() {
        // Initialize our collection of history records and the sorting map
        this.historyRecordsMap = new Map<Id, List<SObject>>();
        this.sortingDatetimeMap = new Map<Id, List<Datetime>>();
    }

    // Class for making history records editable in test context
    public class EditableHistory {
        public String Id { get; set; }
        public String FieldValue { get; set; }
        public String OldValue { get; set; }
        public String NewValue { get; set; }
        public Datetime CreatedDate { get; set; }
    }

    // Mock class for testing history object functionality
    public class MockHistoryObject {
        public Datetime CreatedDate { get; set; }
        public Id Id { get; set; }
        
        public MockHistoryObject(Datetime CreatedDate, Id Id) {
            this.CreatedDate = CreatedDate;
            this.Id = Id;
        }
    }

    // Wrapper class to hold the result of getLatestHistoryValues
    // Contains both the history records map and the sorting datetime map
    @TestVisible
    public class HistoryValuesResult {
        public Map<Id, List<SObject>> historyRecordsMap;
        public Map<Id, List<Datetime>> sortingDatetimeMap;
        
        public HistoryValuesResult(
            Map<Id, List<SObject>> historyRecordsMap,
            Map<Id, List<Datetime>> sortingDatetimeMap
        ) {
            this.historyRecordsMap = historyRecordsMap;
            this.sortingDatetimeMap = sortingDatetimeMap;
        }
    }

    // Called by: getLatestHistoryValues
    // Sorts history records by CreatedDate and ID
    // Used to ensure consistent ordering of history records
    public void sortHistoryList(List<SObject> historyList) {
        List<CustomDatetimeSort> toSort = new List<CustomDatetimeSort>();
        
        for (SObject record : historyList) {
            toSort.add(new CustomDatetimeSort(record));
        }
        
        toSort.sort();
        
        // Replace elements in the original list with the sorted elements
        for (Integer i = 0; i < historyList.size(); i++) {
            historyList[i] = toSort[i].record;
        }
    }

    // Called by: Test classes
    // Test-specific version of sortHistoryList that works with mock objects
    public void sortHistoryList_Test(List<MockHistoryObject> mockHistoryList) {
        // Convert List<MockHistoryObject> to List<SObject> before sorting
        List<SObject> historyList = new List<SObject>();
        for (MockHistoryObject mockRecord : mockHistoryList) {
            SObject record = new Opportunity(); // Replace with the appropriate SObject type
            record.put('CloseDate', mockRecord.CreatedDate.date());
            record.put('Id', mockRecord.Id);
            historyList.add(record);
        }
        
        // Call the existing sortHistoryList method
        sortHistoryList(historyList);
        
        // Convert sorted List<SObject> back to List<MockHistoryObject>
        mockHistoryList.clear();
        for (SObject record : historyList) {
            MockHistoryObject mockRecord = new MockHistoryObject(
                (Datetime) record.get('CloseDate'), // Note the change here
                (Id) record.get('Id')
            );
            mockHistoryList.add(mockRecord);
        }
    }
    
    // Called by: getLatestHistoryValues
    // Helper method to safely convert objects to strings
    @TestVisible
    private static String getStringNotNull(Object valueObj) {
        if (valueObj != null) {
            return String.valueOf(valueObj);
        }
        
        return '';
    }
    
    // Called by: getLatestHistoryValues
    // Determines if an object is custom or standard
    public static Boolean isCustomObject(String objectName) {
        SObjectType sObjectType = Schema.getGlobalDescribe().get(objectName);
        if (sObjectType == null) {
            return false;
        }
        
        return sObjectType.getDescribe().isCustom();
    }
    
    // Called by: getLatestHistoryValues
    // Gets the appropriate history object name based on the tracked object
    @TestVisible
    private static String getHistoryObjectName(String objectName) {
        // Special case: Opportunity
        if (objectName == 'Opportunity') {
            return 'OpportunityFieldHistory';
        }
        
        // Special case: Order
        if (objectName == 'Order') {
            return 'OrderHistory';
        }
        
        // Determine if the object is custom or not
        Boolean isCustom = isCustomObject(objectName);
        
        // Handle standard and custom objects based on the flag
        if (isCustom) {
            // Custom Objects: Remove '__c' and append '__History'
            String cleanedObjectName = objectName.replace('__c', '');
            return cleanedObjectName + '__History';
        } else {
            // Standard Objects: Directly append "History" to the object name
            return objectName + 'History';
        }
    }
    
    // Called by: getLatestHistoryValues
    // Gets the appropriate name field for different object types
    @TestVisible
    private static String getParentName(String objectName) {
        Map<String, String> objectToNameFieldMap = new Map<String, String>{
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
    // Comparator Class for SObject sorting, primarily by CreatedDate and secondarily by ID
    public class CustomDatetimeSort implements Comparable {
        public SObject record;
        
        public CustomDatetimeSort(SObject record) {
            this.record = record;
        }
        
        public Integer compareTo(Object compareTo) {
            CustomDatetimeSort compareToRecord = (CustomDatetimeSort) compareTo;
            
            Datetime thisDate = (Datetime) this.record.get('CreatedDate');
            Datetime otherDate = (Datetime) compareToRecord.record.get(
                'CreatedDate'
            );
            if (thisDate == null)
                return 1;
            if (otherDate == null)
                return -1;
            
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
    
    // Request class for the invocable method
    global class ListenerFlowLatestRequest {
        @InvocableVariable
        global Listener__c listenerConfig;
        
        @InvocableVariable
        global Datetime lastExecutionOn;
    }
    
    // Static variable to hold listener configurations
    public static List<ListenerFlowLatestRequest> listenerConfigList;
    
    // Called by: getLatestHistoryValues
    // Gets a list of history record IDs to exclude from queries
    // Used to prevent duplicate processing of history records
    private static List<Id> getHistoryRecordIdsToExclude() {
        List<Id> idsToExclude = new List<Id>();
        for (Flowdometer__Step__c step : [
            SELECT Flowdometer__History_Record_ID__c
            FROM Flowdometer__Step__c
            WHERE Flowdometer__History_Record_ID__c != NULL
            ORDER BY CreatedDate DESC
            LIMIT 1000
        ]) {
            System.debug('in getHistoryRecordIdsToExclude');
            Limits.getCpuTime();
            idsToExclude.add(step.Flowdometer__History_Record_ID__c);
        }
        return idsToExclude;
    }
    
    // Called by: getLatestHistoryValues
    // Builds the SOQL query string based on the listener configuration and query modifiers
    // Includes security checks and validation to prevent SOQL injection
    @TestVisible
    private static String buildQuery(
        String tableName,
        String parentIdField,
        List<Id> targetRecordIds,
        Listener__c listenerConfig,
        Boolean isHistoryQuery,
        Datetime lastExecutionOn
    ) {
        List<String> selectFields = new List<String>{ 'Id' };
        List<String> whereConditions = new List<String>();
        
        String fieldValue = 'created';
        // Log the field name being tracked for debugging
        System.debug(LoggingLevel.INFO, 'Tracking field: ' + fieldValue);
        
        // Validate field name to track before adding it to the query
        if (String.isBlank(listenerConfig.Field_To_Track__c)) {
            throw new CustomException('Field_To_Track__c is not set in listenerConfig');
        }
        // We no longer declare fieldName here, we just validate it
        // String fieldName = listenerConfig.Field_To_Track__c;
        
        // Log the field name after initialization
        System.debug(LoggingLevel.INFO, 'Initialized fieldName: ' + listenerConfig.Field_To_Track__c);
        
        // Handle the fields to select and the WHERE conditions based on query type
        if (isHistoryQuery) {
            selectFields.addAll(
                new List<String>{
                    'Field',
                    'OldValue',
                    'NewValue',
                    'CreatedDate',
                    parentIdField
                }
            );
            // Include the tracked field plus the special "created" marker row
            whereConditions.add('(Field =: fieldValue OR Field =: fieldName)');
            if (!targetRecordIds.isEmpty()) {
                whereConditions.add(parentIdField + ' IN :targetRecordIds');
            }
            if (lastExecutionOn == null) {
                historyRecordIdsToExclude = getHistoryRecordIdsToExclude();
                if (!historyRecordIdsToExclude.isEmpty()) {
                    whereConditions.add('Id NOT IN :historyRecordIdsToExclude');
                }
            }
        } else {
            // Ensure we only select valid field names that cannot be manipulated
            if (listenerConfig.Object_Name__c == 'Case') {
                selectFields.add('CaseNumber');
            } else {
                selectFields.add('Name');
            }
            
            // Validate field name to track before adding it to the query
            if (String.isNotBlank(listenerConfig.Field_To_Track__c)) {
                // Ensure the object exists in schema
                Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(listenerConfig.Object_Name__c);
                if (sObjectType != null) {
                    Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
                    
                    // Check if field exists on the object
                    if (fieldMap.containsKey(listenerConfig.Field_To_Track__c.toLowerCase())) {
            selectFields.add(listenerConfig.Field_To_Track__c);
                    }
                }
            }
            
            // Only add Type field if it's not null and is a valid field
            if (String.isNotBlank(listenerConfig.Type__c)) {
                Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(listenerConfig.Object_Name__c);
                if (sObjectType != null) {
                    Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
                    
                    // Check if the Type field exists on the object
                    if (fieldMap.containsKey(listenerConfig.Type__c.toLowerCase())) {
                selectFields.add(listenerConfig.Type__c);
                    }
                }
            }
        }
        
        // Get query modifiers
        Map<String, Object> queryModifiers = getQueryModifiers(
            isHistoryQuery,
            lastExecutionOn
        );
        if (String.isNotBlank((String) queryModifiers.get('whereClause'))) {
            whereConditions.add((String) queryModifiers.get('whereClause'));
        }
        
        // Construct the query
        // Validate tableName against known objects to prevent injection
        if (!Schema.getGlobalDescribe().containsKey(tableName)) {
            throw new CustomException('Invalid object name: ' + tableName);
        }
        
        // Use a StringBuilder approach for better security and performance
        String queryStr = 'SELECT ' + String.join(selectFields, ', ') + ' FROM ' + tableName;
        
        if (!whereConditions.isEmpty()) {
            queryStr += ' WHERE ' + String.join(whereConditions, ' AND ');
        }
        
        // Common query modifiers
        if ((Boolean) queryModifiers.get('includeOrderBy')) {
            queryStr += isHistoryQuery
                ? ' ORDER BY ' + parentIdField + ', CreatedDate ASC'
                : ' ORDER BY Id, CreatedDate ASC';
        }
        if ((Boolean) queryModifiers.get('includeLimit')) {
            queryStr += ' LIMIT 1500';
        }
        
        return queryStr;
    }
    
    @TestVisible
    private static Map<String, Object> getQueryModifiers(
        Boolean isHistoryQuery,
        Datetime lastExecutionOn
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
    
    // Called by: parseRecordsToFlow
    // Fetches the latest history records for given parent records based on listener configuration and query modifiers
    // Handles CPU limits, large object detection, and error handling
    @TestVisible
    private static HistoryValuesResult getLatestHistoryValues(
        List<Id> targetRecordIds,
        Listener__c listenerConfig,
        Datetime lastExecutionOn,
        ListenerFlowController controllerInstance,
        String objHistoryName,
        String parentIdField
    ) {
        // Add CPU limit protection
        if (Limits.getCpuTime() > Limits.getLimitCpuTime() * 0.7) {
            System.debug(LoggingLevel.ERROR, 'Approaching CPU limit in getLatestHistoryValues for ' + 
                listenerConfig.Object_Name__c + '.' + listenerConfig.Field_To_Track__c + '. Returning empty result.');
            
            return new HistoryValuesResult(
                new Map<Id, List<SObject>>(),
                new Map<Id, List<Datetime>>()
            );
        }
        
        controllerInstance.sortingDatetimeMap.clear();
        String fieldValue = 'created';
        // Define fieldName variable here at this scope level so it's available for query execution
        String fieldName = listenerConfig.Field_To_Track__c;
        String objectSuffix = '__c';
        Boolean isHistoryQuery = true;
        
        // Check if this is a large object
        Boolean isLargeObject = false;
        Integer maxRecordsToProcess = 1000; // Default limit
        
        try {
            // Try to get a count of history records before running the full query
            String countQuery = 'SELECT COUNT() FROM ' + objHistoryName + ' LIMIT 50000';
            Integer historyRecordCount = Database.countQuery(countQuery);
            isLargeObject = (historyRecordCount > 5000); // If more than 5K history records, consider it large
            
            if (isLargeObject) {
                System.debug(LoggingLevel.WARN, 'Large history object detected: ' + objHistoryName + 
                    ' with ' + historyRecordCount + ' records. Limiting query results.');
                // Reduce the limit for large objects
                maxRecordsToProcess = 500;
            }
        } catch (Exception e) {
            // If count query fails, just log and continue with default limit
            System.debug(LoggingLevel.WARN, 'Unable to determine record count for ' + objHistoryName + 
                ': ' + e.getMessage());
        }
        
        String queryStr = buildQuery(
            objHistoryName,
            parentIdField,
            targetRecordIds,
            listenerConfig,
            true,
            lastExecutionOn
        );
        
        // Add an explicit LIMIT clause for large objects
        if (isLargeObject && !queryStr.containsIgnoreCase(' LIMIT ')) {
            queryStr = queryStr + ' LIMIT ' + maxRecordsToProcess;
        }
        
        System.debug('History query built: ' + queryStr);
        
        // Validate the query string to prevent SOQL injection
        if (!queryStr.startsWithIgnoreCase('SELECT ') || 
            queryStr.containsIgnoreCase('INSERT') || 
            queryStr.containsIgnoreCase('UPDATE') || 
            queryStr.containsIgnoreCase('DELETE') || 
            queryStr.containsIgnoreCase('UNDELETE') ||
            queryStr.containsIgnoreCase(';')) {
            throw new CustomException('Invalid query structure detected: possible injection attempt');
        }
        
        // Query for history records
        Map<Id, List<SObject>> historyRecordsMap = controllerInstance.historyRecordsMap;
        Datetime queryTimestamp = Datetime.now();
        
        // HISTORY RECORDS QUERY to populate historyRecordsMap and sortingDatetimeMap
        Integer startCpuTime = Limits.getCpuTime();
        Integer cpuTimeLimit = Math.min(Limits.getLimitCpuTime() * 7 / 10, 9000); // 70% of limit or max 9000
        Integer recordsProcessed = 0;
        
        try {
            for (SObject obj : Database.query(queryStr)) {
                recordsProcessed++;
            
                // Check the CPU time regularly to avoid timeouts
                if (Math.mod(recordsProcessed, 100) == 0 && Limits.getCpuTime() - startCpuTime > cpuTimeLimit) {
                    System.debug(LoggingLevel.ERROR, 'CPU limit approaching during history processing. ' + 
                        'Processed ' + recordsProcessed + ' records before stopping.');
                break;
            }
            
            Id parentId = (Id) obj.get(parentIdField);
            Datetime createdDate = (Datetime) obj.get('CreatedDate');
            
            // Optimize map access for historyRecordsMap
            List<SObject> historyList = historyRecordsMap.get(parentId);
                if (historyList == null) {
                historyList = new List<SObject>();
                historyRecordsMap.put(parentId, historyList);
            }
            historyList.add(obj);
            
            // Optimize map access for sortingDatetimeMap
            List<Datetime> dateTimeList = controllerInstance.sortingDatetimeMap.get(parentId);
                if (dateTimeList == null) {
                dateTimeList = new List<Datetime>();
                controllerInstance.sortingDatetimeMap.put(parentId, dateTimeList);
            }
            dateTimeList.add(createdDate);
        }
        
            System.debug(LoggingLevel.INFO, 'Successfully processed ' + recordsProcessed + 
                ' history records for ' + listenerConfig.Object_Name__c + '.' + listenerConfig.Field_To_Track__c);
            
            // Only update Last Execution On if we have history records, otherwise we'll keep querying for the same records
            if (!historyRecordsMap.isEmpty()) {
            listenerConfig.Flowdometer__Last_Execution_On__c = queryTimestamp;
                
            // Sort using sortHistoryList method
                for (Id parentId : historyRecordsMap.keySet()) {
                    List<SObject> specificHistoryList = historyRecordsMap.get(parentId);
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
                    if (parentRecord != null) {
                        Object currentFieldValue = parentRecord.get(fieldValue);
                
                // Optionally, update the historyRecordsMap
                        historyRecordsMap.put(oneHistoryParentId, new List<SObject>{ createdHistoryRecord });
                    }
            }
        }
        
        // Handle the createdHistoryMap logic
            if (!createdHistoryMap.isEmpty()) {
                for (Id parentId : createdHistoryMap.keySet()) {
                    if (historyRecordsMap.containsKey(parentId)) {
                    List<SObject> tempList = historyRecordsMap.get(parentId);
                        if (!tempList.isEmpty()) {
                    tempList.remove(tempList.size() - 1);
                    tempList.add(createdHistoryMap.get(parentId));
                    historyRecordsMap.put(parentId, tempList);
                }
            }
        }
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error querying history records: ' + e.getMessage() + 
                '\nQuery: ' + queryStr);
            
            // Add more detailed error message and stack trace
            String detailedError = 'Error querying history records: ' + e.getMessage() + 
                                   '\nStack trace: ' + e.getStackTraceString() +
                                   '\nQuery: ' + queryStr;
            
            // Log error but continue with empty results
            listenerConfig.Error_Message__c = detailedError;
            
            // Update retry count for this listener if we have an ID
            if (listenerConfig.Id != null) {
                Integer currentRetryCount = retryCountMap.containsKey(listenerConfig.Id) ? 
                                           retryCountMap.get(listenerConfig.Id) : 0;
                retryCountMap.put(listenerConfig.Id, currentRetryCount + 1);
                
                // Add retry info to error message
                listenerConfig.Error_Message__c += '\nRetry count: ' + (currentRetryCount + 1) + 
                                                   ' of ' + MAX_RETRY_COUNT;
            }
        }
        
        // Return both maps in a wrapper class
        return new HistoryValuesResult(
            controllerInstance.historyRecordsMap,
            controllerInstance.sortingDatetimeMap
        );
    }
    
    // Main method for querying and processing history records
    // Handles batching, error handling, and retry logic
    @InvocableMethod(
        Label='Query & Parse History Records'
        Description='Used to query History Records in Flow'
        Category='ListenerFlowController'
    )
    public static List<ListenerFlowLatestResponse> parseRecordsToFlow(
        List<ListenerFlowLatestRequest> listenerConfigList
    ) {
        //START DEBUG - Enhanced logging for debugging
        Listener__c firstListenerConfig = listenerConfigList[0].listenerConfig;
        String objectName = firstListenerConfig.Object_Name__c;
        String fieldName = firstListenerConfig.Field_To_Track__c;
        System.debug(LoggingLevel.INFO, '### FLOWDOMETER DEBUG: Processing listener for: Object=' + objectName + ', Field=' + fieldName);
        
        // Check for retry limits
        Id listenerId = firstListenerConfig.Id;
        if (listenerId != null) {
            Integer currentRetryCount = retryCountMap.containsKey(listenerId) ? retryCountMap.get(listenerId) : 0;
            if (currentRetryCount >= MAX_RETRY_COUNT) {
                System.debug(LoggingLevel.ERROR, 'Maximum retry count reached for listener: ' + listenerId);
                ListenerFlowLatestResponse maxRetriesResponse = new ListenerFlowLatestResponse();
                maxRetriesResponse.hasRecords = false;
                maxRetriesResponse.isCheckSuccess = false;
                
                firstListenerConfig.Error_Message__c = 'Maximum retry count (' + MAX_RETRY_COUNT + ') reached. Please contact your administrator or check debug logs.';
                try {
                    update firstListenerConfig;
                } catch(Exception ex) {
                    System.debug(LoggingLevel.ERROR, 'Failed to update listener record with error: ' + ex.getMessage());
                }
                
                return new List<ListenerFlowLatestResponse>{maxRetriesResponse};
            }
            // Increment retry count for this listener
            retryCountMap.put(listenerId, currentRetryCount + 1);
        }
        
        // Actual method implementation starts here
        List<ListenerFlowLatestResponse> responseList = new List<ListenerFlowLatestResponse>();
        List<String> errorMessages = new List<String>();
        
        try {
            // Create a response object for this invocation
            ListenerFlowLatestResponse response = new ListenerFlowLatestResponse();
            
            // Check if we have listener configs to process
            if (listenerConfigList == null || listenerConfigList.isEmpty()) {
                throw new CustomException('No listener configurations provided');
            }
            
            // Process each listener config
            for (ListenerFlowLatestRequest request : listenerConfigList) {
                // Initialize variables
                ListenerFlowController controllerInstance = new ListenerFlowController();
                Listener__c listenerConfig = request.listenerConfig;
                Datetime lastExecutionOn = request.lastExecutionOn;
                
                // Special handling for certain object types
                if (listenerConfig.Object_Name__c == 'Order') {
                    System.debug(LoggingLevel.WARN, 'Processing Order object which may have performance limitations');
                    // For Order objects, we'll be more aggressive with CPU limit checking
                    if (Limits.getCpuTime() > Limits.getLimitCpuTime() * 0.5) {
                        String errorMsg = 'CPU limit approaching for Order object. Consider breaking into smaller batches.';
                        errorMessages.add(errorMsg);
                        System.debug(LoggingLevel.ERROR, errorMsg);
                        response.isCheckSuccess = false;
                        response.hasRecords = false;
                        
                        listenerConfig.Error_Message__c = errorMsg;
                        update listenerConfig;
                        
                        responseList.add(response);
                        continue; // Skip to next listener config
                    }
                }
                
                try {
                    // BEFORE querying new history, process any previously stored unprocessed history records
                    String unprocessedRecordsJson = listenerConfig.Flowdometer__Unprocessed_History_Records__c;
                    if (String.isNotBlank(unprocessedRecordsJson)) {
                        List<ListenerFlowController> lstListenerFlow = (List<ListenerFlowController>) JSON.deserialize(unprocessedRecordsJson, List<ListenerFlowController>.class);
                        response.lstListenerFlow = lstListenerFlow;
                        response.hasRecords = !lstListenerFlow.isEmpty();
                        response.isCheckSuccess = true;

                        // Batch size can be configurable; using 20 as the legacy default
                        Integer batchSize = 20;
                        Map<Id, Boolean> processedRecordsMap = new Map<Id, Boolean>();

                        // Use existing helper to split batches and serialize leftovers
                        controllerInstance.handleBatchAndUnprocessedRecords(
                            response,
                            listenerConfig,
                            batchSize,
                            processedRecordsMap
                        );

                        // Skip the remainder of the loop; this listener will be handled in the next scheduled run if leftovers remain
                        responseList.add(response);
                        continue;
                    }
                    
                    // Get history records since last execution
                    String objName = listenerConfig.Object_Name__c;
                    String objHistoryName = getHistoryObjectName(objName);
                    
                    // Determine the parent ID field name based on object type
                    String parentIdField = isCustomObject(objName) ? 'ParentId' : (objName + 'Id');
                    
                    System.debug(LoggingLevel.INFO, 'Fetching history records for: ' + 
                                objHistoryName + ', Parent Field: ' + parentIdField);
                    
                    // Find records that have changes since last execution
                    List<Id> targetRecordIds = new List<Id>();
                    
                    // Get the latest history values
                    HistoryValuesResult historyResult = getLatestHistoryValues(
                        targetRecordIds, 
                        listenerConfig, 
                        lastExecutionOn, 
                        controllerInstance,
                        objHistoryName,
                        parentIdField
                    );
                    
                    System.debug(LoggingLevel.INFO, 'Retrieved history records: ' + 
                                (historyResult.historyRecordsMap != null ? historyResult.historyRecordsMap.size() : 0));
                    
                    // If we have history records, prepare the response
                    if (historyResult.historyRecordsMap != null && !historyResult.historyRecordsMap.isEmpty()) {
                        response.hasRecords = true;

                        // NEW: Query parent records (Opportunities, Cases, etc.) for the history records we just found
                        Set<Id> parentIds = new Set<Id>();
                        parentIds.addAll(historyResult.historyRecordsMap.keySet());

                        Map<Id, SObject> sObjectMap = new Map<Id, SObject>();
                        if (!parentIds.isEmpty()) {
                            String parentNameField = (listenerConfig.Object_Name__c == 'Case') ? 'CaseNumber' : 'Name';
                            String parentQuery = 'SELECT Id, ' + parentNameField + ' FROM ' + listenerConfig.Object_Name__c + ' WHERE Id IN :parentIds';
                            for (SObject sob : Database.query(parentQuery)) {
                                Id sobId = (Id)sob.get('Id');
                                sObjectMap.put(sobId, sob);
                            }
                            controllerInstance.parentRecordsMap = sObjectMap.clone();
                        }
                        // Process history records into a format usable by Flow
                        controllerInstance.preparingResponse(
                            response,
                            listenerConfig,
                            sObjectMap,
                            controllerInstance
                        );
                        // NEW: batch first N records back to Flow and store the rest on the Listener
                        Integer batchSize = 20; // legacy default, could be made configurable later
                        Map<Id, Boolean> processedRecordsMap = new Map<Id, Boolean>();
                        if (response.lstListenerFlow.size() > batchSize) {
                            controllerInstance.handleBatchAndUnprocessedRecords(
                                response,
                                listenerConfig,
                                batchSize,
                                processedRecordsMap
                            );
                        }
                    } else {
                        // No records found
                        response.hasRecords = false;
                        System.debug(LoggingLevel.INFO, 'No history records found for processing');
                    }
                    
                    // Update last execution time on the listener config
                    listenerConfig.Last_Execution_On__c = System.now();
                    update listenerConfig;
                    
                } catch (Exception ex) {
                    // Handle exceptions for this specific listener config
                    String errorMsg = 'Error processing listener for ' + listenerConfig.Object_Name__c + 
                                    ': ' + ex.getMessage();
                    errorMessages.add(errorMsg);
                    System.debug(LoggingLevel.ERROR, errorMsg + '\n' + ex.getStackTraceString());
        
                    // Update the listener config with error message
                    listenerConfig.Error_Message__c = errorMsg;
                    update listenerConfig;
            
                    // Mark this response as having an error
                    response.isCheckSuccess = false;
                }
                
                // Add the response for this listener config
            responseList.add(response);
        }
        
            // If we encountered any errors, throw an exception with all error messages
            if (!errorMessages.isEmpty()) {
                throw new CustomException(String.join(errorMessages, '\n'));
            }
            
            // Return the list of responses
            return responseList;
            
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error in parseRecordsToFlow: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
            
            // Create a generic error response
            ListenerFlowLatestResponse errorResponse = new ListenerFlowLatestResponse();
            errorResponse.isCheckSuccess = false;
            errorResponse.hasRecords = false;
            
            // If we have a listener config, update its error message
            if (!listenerConfigList.isEmpty()) {
                try {
                    Listener__c listenerToUpdate = listenerConfigList[0].listenerConfig;
                    listenerToUpdate.Error_Message__c = 'Failed to process history records: ' + ex.getMessage();
                    update listenerToUpdate;
                } catch (Exception updateEx) {
                    System.debug(LoggingLevel.ERROR, 'Error updating listener with error message: ' + updateEx.getMessage());
        }
            }
            
            return new List<ListenerFlowLatestResponse>{ errorResponse };
        }
    }

    // Called by: parseRecordsToFlow
    // Prepares the response for Flow by processing history records
    // Includes field label translation and history record ID tracking
    @TestVisible
    public void preparingResponse(
        ListenerFlowLatestResponse response,
        Listener__c listenerConfig,
        Map<Id, SObject> sObjectMap,
        ListenerFlowController controllerInstance
    ) {
        // Add CPU limit protection
        if (Limits.getCpuTime() > Limits.getLimitCpuTime() * 0.7) {
            System.debug(LoggingLevel.ERROR, 'Approaching CPU limit in preparingResponse. Returning without processing.');
            response.hasRecords = false;
            return;
        }
        
        // Iterate over the history records map
        for (Id parentId : controllerInstance.historyRecordsMap.keySet()) {
            List<SObject> historyList = controllerInstance.historyRecordsMap.get(parentId);
            
            Id previousHistoryId = null; // track prior history record per parent

            for (SObject historyRecord : historyList) {
                ListenerFlowController listenerFlow = new ListenerFlowController();
                String fieldApi = (String) historyRecord.get('Field');
                // Skip generic "created" field rows – they're not useful for tracking
                if(fieldApi != null && fieldApi.equalsIgnoreCase('created')) {
                    continue;
                }

                // Translate API name to the field's UI label for better readability
                String fieldLabel = fieldApi;
                try {
                    Schema.SObjectType sobType = Schema.getGlobalDescribe().get(listenerConfig.Object_Name__c);
                    if(sobType != null) {
                        Map<String,Schema.SObjectField> fmap = sobType.getDescribe().fields.getMap();
                        Schema.SObjectField fld = fmap.get(fieldApi != null ? fieldApi.toLowerCase() : null);
                        if(fld != null) {
                            fieldLabel = fld.getDescribe().getLabel();
                        }
                    }
                } catch(Exception ignore) {}

                listenerFlow.varCurrentFieldTracked = fieldLabel;
                listenerFlow.varCurrentFieldValue = (String) historyRecord.get('NewValue');
                listenerFlow.varCurrentObjectID = parentId;
                String nameField = (listenerConfig.Object_Name__c == 'Case') ? 'CaseNumber' : 'Name';
                listenerFlow.varNameofTrackedRecord = (String) sObjectMap.get(parentId).get(nameField);
                listenerFlow.varTrackedCustomObjectName = listenerConfig.Object_Name__c;
                listenerFlow.varEditStartTime = (Datetime) historyRecord.get('CreatedDate');
                listenerFlow.varEditEndTime = System.now();
                listenerFlow.varType = listenerConfig.Type__c;

                // Current history record Id
                Id currentHistoryId = (Id) historyRecord.get('Id');
                listenerFlow.varHistoryRecordId = currentHistoryId;

                // Previous history record Id becomes varLastHistoryRecordId (may be null for the first record)
                listenerFlow.varLastHistoryRecordId = previousHistoryId;

                // Add to response list
                response.lstListenerFlow.add(listenerFlow);

                // update previousHistoryId for next iteration
                previousHistoryId = currentHistoryId;
            }
        }
        response.hasRecords = !response.lstListenerFlow.isEmpty();
    }

    // Called by: parseRecordsToFlow
    // Handles batching of records and persistence of unprocessed records
    // Uses SimplifiedListenerFlowController to reduce payload size
    public void handleBatchAndUnprocessedRecords(
        ListenerFlowLatestResponse response,
        Listener__c listenerConfig,
        Integer batchSize,
        Map<Id, Boolean> processedRecordsMap
    ) {
        List<SimplifiedListenerFlowController> remainingRecords = new List<SimplifiedListenerFlowController>();
        if (response.lstListenerFlow.isEmpty()) {
            return;
        }

        // Dynamically adjust batch size downwards if fewer records than the default
        if (response.lstListenerFlow.size() < batchSize) {
            batchSize = response.lstListenerFlow.size();
        }

        // 1. Extract the first batch to send back to Flow
        List<ListenerFlowController> firstBatch = new List<ListenerFlowController>();
        for (Integer i = 0; i < batchSize; i++) {
            ListenerFlowController item = response.lstListenerFlow[i];
            firstBatch.add(item);
            processedRecordsMap.put(item.varHistoryRecordId, true);
        }

        // 2. Convert remaining records into a lightweight JSON for storage
        for (Integer i = batchSize; i < response.lstListenerFlow.size(); i++) {
            ListenerFlowController original = response.lstListenerFlow[i];
            if (processedRecordsMap.containsKey(original.varHistoryRecordId)) {
                continue; // already processed this record
            }
            SimplifiedListenerFlowController simplified = new SimplifiedListenerFlowController();
            simplified.varType = original.varType;
            simplified.varTrackedCustomObjectName = original.varTrackedCustomObjectName;
            simplified.varEditStartTime = original.varEditStartTime;
            simplified.varEditEndTime = original.varEditEndTime;
            simplified.varCurrentObjectID = original.varCurrentObjectID;
            simplified.varCurrentFieldTracked = original.varCurrentFieldTracked;
            simplified.varCurrentFieldValue = original.varCurrentFieldValue;
            simplified.varNameofTrackedRecord = original.varNameofTrackedRecord;
            simplified.varHistoryRecordId = original.varHistoryRecordId;
            simplified.varLastHistoryRecordId = original.varLastHistoryRecordId;
            remainingRecords.add(simplified);
        }

        // Serialize leftovers, keeping under the 131,072-char long-text limit
        String remainingRecordsJson = remainingRecords.isEmpty() ? null : JSON.serialize(remainingRecords);
        Integer fieldLimit = 131072;
        while (remainingRecordsJson != null && remainingRecordsJson.length() > fieldLimit) {
            // drop the oldest record until we fit
            remainingRecords.remove(0);
            remainingRecordsJson = remainingRecords.isEmpty() ? null : JSON.serialize(remainingRecords);
        }

        // Persist leftovers (or clear the field if none left)
        listenerConfig.Flowdometer__Unprocessed_History_Records__c = remainingRecordsJson;
        update listenerConfig;

        // Finally give Flow only the first batch for this run
        response.lstListenerFlow = firstBatch;
        response.hasRecords = !response.lstListenerFlow.isEmpty();
    }

    // Called by: parseRecordsToFlow
    // Overloaded version of preparingResponse that supports history tracking flag
    @TestVisible
    public void preparingResponse(
        ListenerFlowLatestResponse response,
        Listener__c listenerConfig,
        Map<Id, SObject> sObjectMap,
        ListenerFlowController controllerInstance,
        Boolean enableHistoryTracking
    ) {
        // If history tracking is explicitly disabled, just mark no records and exit
        if(enableHistoryTracking == false) {
            response.hasRecords = false;
            return;
        }
        // Delegate to 4-arg version
        preparingResponse(response, listenerConfig, sObjectMap, controllerInstance);
    }

    // Called by: parseRecordsToFlow
    // Overloaded version of preparingResponse that supports String-keyed maps
    @TestVisible
    public void preparingResponse(
        ListenerFlowLatestResponse response,
        Listener__c listenerConfig,
        Map<String, SObject> sObjectMap,
        ListenerFlowController controllerInstance
    ) {
        // Convert the String-keyed map into an Id-keyed map
        Map<Id, SObject> converted = new Map<Id, SObject>();
        for(String strId : sObjectMap.keySet()) {
            try {
                converted.put(Id.valueOf(strId), sObjectMap.get(strId));
            } catch(Exception ex) {
                // ignore non-Id keys
            }
        }
        preparingResponse(response, listenerConfig, converted, controllerInstance);
    }

    // Called by: parseRecordsToFlow
    // Overloaded version of preparingResponse that supports both String-keyed maps and history tracking
    @TestVisible
    public void preparingResponse(
        ListenerFlowLatestResponse response,
        Listener__c listenerConfig,
        Map<String, SObject> sObjectMap,
        ListenerFlowController controllerInstance,
        Boolean enableHistoryTracking
    ) {
        if(enableHistoryTracking == false) {
            response.hasRecords = false;
            return;
        }
        // Convert then delegate
        Map<Id, SObject> converted = new Map<Id, SObject>();
        for(String strId : sObjectMap.keySet()) {
            try {
                converted.put(Id.valueOf(strId), sObjectMap.get(strId));
            } catch(Exception ex) {}
        }
        preparingResponse(response, listenerConfig, converted, controllerInstance);
    }
}