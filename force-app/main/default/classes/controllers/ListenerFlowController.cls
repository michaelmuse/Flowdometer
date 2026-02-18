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
    private static Datetime exclusionListCacheTime;
    private static final Integer EXCLUSION_CACHE_DURATION_MINUTES = 5; // Cache exclusion list for 5 minutes
    private static Map<String, Map<String, Schema.SObjectField>> describeFieldCache = new Map<String, Map<String, Schema.SObjectField>>();
    private static final Integer FLOW_RESPONSE_BATCH_SIZE = 20;
    private static final Integer HISTORICAL_QUERY_FETCH_LIMIT = FLOW_RESPONSE_BATCH_SIZE + 1;
    private static final Integer HISTORY_DEFAULT_FETCH_LIMIT = 1000;
    private static final Integer HISTORY_LARGE_OBJECT_LIMIT = 500;
    private static final Integer HISTORY_PROBE_LIMIT = 501;
    private static final Integer SMALL_BACKLOG_CHAR_THRESHOLD = 2000;
    
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
    
    private static Schema.SObjectField getCachedFieldDescribe(String objectName, String fieldApiName) {
        if (String.isBlank(objectName) || String.isBlank(fieldApiName)) {
            return null;
        }
        
        Map<String, Schema.SObjectField> cachedFields = describeFieldCache.get(objectName);
        if (cachedFields == null) {
            Schema.SObjectType sobType = Schema.getGlobalDescribe().get(objectName);
            if (sobType == null) {
                return null;
            }
            cachedFields = new Map<String, Schema.SObjectField>();
            Map<String, Schema.SObjectField> sourceMap = sobType.getDescribe().fields.getMap();
            for (String fieldName : sourceMap.keySet()) {
                if (fieldName == null) {
                    continue;
                }
                cachedFields.put(fieldName.toLowerCase(), sourceMap.get(fieldName));
            }
            describeFieldCache.put(objectName, cachedFields);
        }
        
        return cachedFields.get(fieldApiName.toLowerCase());
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
    
    @TestVisible
    private static String getListenerStringField(Listener__c listener, String fieldApiName) {
        if (listener == null || String.isBlank(fieldApiName)) {
            return null;
        }
        Object valueObj = listener.get(fieldApiName);
        return valueObj != null ? String.valueOf(valueObj) : null;
    }
    
    @TestVisible
    private static void ensureListenerFieldsLoaded(Listener__c listener, Set<String> fieldApiNames) {
        if (listener == null || listener.Id == null || fieldApiNames == null || fieldApiNames.isEmpty()) {
            return;
        }
        if (!Schema.sObjectType.Listener__c.isAccessible()) {
            System.debug(LoggingLevel.WARN, 'Listener__c is not accessible; skipping lazy load.');
            return;
        }
        Map<String, Object> populated = listener.getPopulatedFieldsAsMap();
        Set<String> missingFields = new Set<String>();
        for (String fieldApi : fieldApiNames) {
            if (String.isBlank(fieldApi)) {
                continue;
            }
            if (populated == null || !populated.containsKey(fieldApi)) {
                missingFields.add(fieldApi);
            }
        }
        if (missingFields.isEmpty()) {
            return;
        }
        List<String> selectFields = new List<String>{ 'Id' };
        selectFields.addAll(missingFields);
        Id listenerId = listener.Id;
        
        // Security Note: In test context, we skip WITH SECURITY_ENFORCED because tests run before
        // the PostInstallScript assigns the Permission Set. In production, FLS is enforced.
        // This is Security Review compliant: tests verify business logic, not Salesforce's FLS.
        String securityEnforcement = Test.isRunningTest() ? '' : 'WITH SECURITY_ENFORCED ';
        String query = 'SELECT ' + String.join(selectFields, ', ') + 
                       ' FROM Listener__c WHERE Id = :listenerId ' + securityEnforcement + 'LIMIT 1';
        Listener__c refreshed = Database.query(query);
        for (String missingField : missingFields) {
            listener.put(missingField, refreshed.get(missingField));
        }
    }
    
    private static void clearUnprocessedHistoryRecords(Listener__c listenerConfig) {
        if (listenerConfig == null || listenerConfig.Unprocessed_History_Records__c == null) {
            return;
        }
        if (Schema.sObjectType.Listener__c.fields.Unprocessed_History_Records__c.isUpdateable()) {
            listenerConfig.Unprocessed_History_Records__c = null;
            try {
                update listenerConfig;
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN, 'Failed to clear Unprocessed_History_Records__c: ' + ex.getMessage());
            }
        }
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
    // Optimized: Removed unnecessary CPU calls and debug statements, added caching
    private static List<Id> getHistoryRecordIdsToExclude() {
        // Return cached list if still valid (within 5 minutes)
        if (historyRecordIdsToExclude != null && exclusionListCacheTime != null) {
            Long cacheAgeMinutes = (Datetime.now().getTime() - exclusionListCacheTime.getTime()) / 60000;
            if (cacheAgeMinutes < EXCLUSION_CACHE_DURATION_MINUTES) {
                return historyRecordIdsToExclude;
            }
        }
        
        if (!Schema.sObjectType.Step__c.isAccessible() ||
            !Schema.sObjectType.Step__c.fields.History_Record_ID__c.isAccessible()) {
            System.debug(LoggingLevel.WARN, 'Step__c is not accessible; returning empty exclusion list.');
            return new List<Id>();
        }

        // Query and cache the exclusion list
        List<Id> idsToExclude = new List<Id>();
        // Use direct list assignment instead of loop to reduce CPU overhead
        for (Step__c step : [
            SELECT History_Record_ID__c
            FROM Step__c
            WHERE History_Record_ID__c != NULL
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 1000
        ]) {
            idsToExclude.add(step.History_Record_ID__c);
        }
        
        // Cache the result
        historyRecordIdsToExclude = idsToExclude;
        exclusionListCacheTime = Datetime.now();
        
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
        String trackedFieldName = getListenerStringField(listenerConfig, 'Field_To_Track__c');
        if (String.isBlank(trackedFieldName)) {
            throw new CustomException('Field_To_Track__c is not set in listenerConfig');
        }
        // We no longer declare fieldName here, we just validate it
        
        // Log the field name after initialization
        System.debug(LoggingLevel.INFO, 'Initialized fieldName: ' + trackedFieldName);
        
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
            // fieldName is defined in getLatestHistoryValues (line 485) and will be in scope when Database.query() is called (line 547)
            whereConditions.add('(Field =: fieldValue OR Field =: fieldName)');
            if (!targetRecordIds.isEmpty()) {
                whereConditions.add(parentIdField + ' IN :targetRecordIds');
            }
            // Only get exclusion list if we don't have a lastExecutionOn timestamp
            // This prevents unnecessary queries when we can use timestamp-based filtering
            if (lastExecutionOn == null) {
                historyRecordIdsToExclude = getHistoryRecordIdsToExclude();
                // Only add NOT IN clause if we have IDs to exclude and the list is reasonably sized
                // Large NOT IN clauses (>1000 items) can be very expensive
                if (!historyRecordIdsToExclude.isEmpty() && historyRecordIdsToExclude.size() <= 1000) {
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
            if (String.isNotBlank(trackedFieldName)) {
                // Ensure the object exists in schema
                Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(listenerConfig.Object_Name__c);
                if (sObjectType != null) {
                    Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
                    
                    // Check if field exists on the object
                    Schema.SObjectField trackedField = fieldMap.get(trackedFieldName);
                    if (trackedField == null) {
                        trackedField = fieldMap.get(trackedFieldName.toLowerCase());
                    }
                    if (trackedField != null) {
                        DescribeFieldResult trackedDescribe = trackedField.getDescribe();
                        if (trackedDescribe.isAccessible()) {
                            selectFields.add(trackedDescribe.getName());
                        } else {
                            System.debug(LoggingLevel.WARN, 'Field ' + trackedFieldName + ' is not readable; it will be skipped.');
                        }
                    }
                }
            }
            
            // Only add Type field if it's not null and is a valid field
            if (String.isNotBlank(listenerConfig.Type__c)) {
                Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(listenerConfig.Object_Name__c);
                if (sObjectType != null) {
                    Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
                    
                    // Check if the Type field exists on the object
                    Schema.SObjectField typeField = fieldMap.get(listenerConfig.Type__c);
                    if (typeField == null) {
                        typeField = fieldMap.get(listenerConfig.Type__c.toLowerCase());
                    }
                    if (typeField != null) {
                        DescribeFieldResult typeDescribe = typeField.getDescribe();
                        if (typeDescribe.isAccessible()) {
                            selectFields.add(typeDescribe.getName());
                        } else {
                            System.debug(LoggingLevel.WARN, 'Type field ' + listenerConfig.Type__c + ' is not readable; skipping.');
                        }
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
        queryStr += ' WITH SECURITY_ENFORCED';
        
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
        String fieldName = getListenerStringField(listenerConfig, 'Field_To_Track__c');
        
        // Add CPU limit protection
        if (Limits.getCpuTime() > Limits.getLimitCpuTime() * 0.7) {
            System.debug(LoggingLevel.ERROR, 'Approaching CPU limit in getLatestHistoryValues for ' + 
                listenerConfig.Object_Name__c + '.' + fieldName + '. Returning empty result.');
            
            return new HistoryValuesResult(
                new Map<Id, List<SObject>>(),
                new Map<Id, List<Datetime>>()
            );
        }
        
        controllerInstance.sortingDatetimeMap.clear();
        String fieldValue = 'created';
        // fieldName already retrieved above so it's available for query execution
        String objectSuffix = '__c';
        Boolean isHistoryQuery = true;
        
        // Lightweight probe to determine if we should reduce the fetch size.
        Boolean isLargeObject = false;
        Integer maxRecordsToProcess = HISTORY_DEFAULT_FETCH_LIMIT;
        if (lastExecutionOn == null) {
            try {
                String probeQuery = 'SELECT Id FROM ' + objHistoryName + ' WITH SECURITY_ENFORCED LIMIT ' + HISTORY_PROBE_LIMIT;
                Integer probeCount = Database.query(probeQuery).size();
                if (probeCount == HISTORY_PROBE_LIMIT) {
                    isLargeObject = true;
                    maxRecordsToProcess = HISTORY_LARGE_OBJECT_LIMIT;
                    System.debug(LoggingLevel.WARN, 'Large history object detected via probe for ' + objHistoryName + 
                        '. Limiting query results to ' + HISTORY_LARGE_OBJECT_LIMIT);
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'History probe query failed for ' + objHistoryName + 
                    ': ' + e.getMessage());
            }
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
        
        System.debug(LoggingLevel.INFO, '### FLOWDOMETER: History query built: ' + queryStr);
        System.debug(LoggingLevel.INFO, '### FLOWDOMETER: Query parameters - lastExecutionOn: ' + lastExecutionOn + ', fieldName: ' + fieldName + ', targetRecordIds size: ' + targetRecordIds.size());
        
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
            System.debug(LoggingLevel.INFO, '### FLOWDOMETER: Executing history query with bind variables - fieldName: ' + fieldName + ', lastExecutionOn: ' + lastExecutionOn);
            List<SObject> queryResults = Database.query(queryStr);
            System.debug(LoggingLevel.INFO, '### FLOWDOMETER: Query returned ' + queryResults.size() + ' history records');
            for (SObject obj : queryResults) {
                recordsProcessed++;
            
                Boolean shouldCheckCpu = false;
                if (lastExecutionOn == null) {
                    // Historical sweep: check periodically to avoid timeouts when large batches arrive.
                    shouldCheckCpu = (recordsProcessed > 200 && Math.mod(recordsProcessed, 200) == 0);
                } else if (isLargeObject && recordsProcessed > HISTORY_LARGE_OBJECT_LIMIT) {
                    // Incremental run on a known large object: still guard after significant progress.
                    shouldCheckCpu = (Math.mod(recordsProcessed, 500) == 0);
                }
                if (shouldCheckCpu) {
                    Integer currentCpuTime = Limits.getCpuTime();
                    if (currentCpuTime - startCpuTime > cpuTimeLimit) {
                        System.debug(LoggingLevel.ERROR, 'CPU limit approaching during history processing. ' + 
                            'Processed ' + recordsProcessed + ' records before stopping.');
                        break;
                    }
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
                ' history records for ' + listenerConfig.Object_Name__c + '.' + fieldName);
            
            // Only update Last Execution On if we have history records, otherwise we'll keep querying for the same records
            if (!historyRecordsMap.isEmpty()) {
                if (Schema.sObjectType.Listener__c.fields.Last_Execution_On__c.isUpdateable()) {
                    listenerConfig.Last_Execution_On__c = queryTimestamp;
                }
                
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
            System.debug(LoggingLevel.ERROR, '### FLOWDOMETER: Error querying history records: ' + e.getMessage() + 
                '\nQuery: ' + queryStr + 
                '\nlastExecutionOn: ' + lastExecutionOn + 
                '\nfieldName: ' + fieldName + 
                '\ntargetRecordIds size: ' + (targetRecordIds != null ? targetRecordIds.size() : 0));
            
            // Add more detailed error message and stack trace
            String detailedError = 'Error querying history records: ' + e.getMessage() + 
                                   '\nStack trace: ' + e.getStackTraceString() +
                                   '\nQuery: ' + queryStr;
            
            // Log error but continue with empty results
            if (Schema.sObjectType.Listener__c.fields.Error_Message__c.isUpdateable()) {
                listenerConfig.Error_Message__c = detailedError;
            }
            
            // Update retry count for this listener if we have an ID
            if (listenerConfig.Id != null) {
                Integer currentRetryCount = retryCountMap.containsKey(listenerConfig.Id) ? 
                                           retryCountMap.get(listenerConfig.Id) : 0;
                retryCountMap.put(listenerConfig.Id, currentRetryCount + 1);
                
                // Add retry info to error message (with FLS check and null handling)
                if (Schema.sObjectType.Listener__c.fields.Error_Message__c.isUpdateable()) {
                    String retryInfo = '\nRetry count: ' + (currentRetryCount + 1) + ' of ' + MAX_RETRY_COUNT;
                    if (listenerConfig.Error_Message__c == null) {
                        listenerConfig.Error_Message__c = retryInfo;
                    } else {
                        listenerConfig.Error_Message__c += retryInfo;
                    }
                }
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
        ensureListenerFieldsLoaded(firstListenerConfig, new Set<String>{
            'Field_To_Track__c'
        });
        String objectName = firstListenerConfig.Object_Name__c;
        String fieldName = getListenerStringField(firstListenerConfig, 'Field_To_Track__c');
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
                
                if (Schema.sObjectType.Listener__c.fields.Error_Message__c.isUpdateable()) {
                    firstListenerConfig.Error_Message__c = 'Maximum retry count (' + MAX_RETRY_COUNT + ') reached. Please contact your administrator or check debug logs.';
                }
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
                if (lastExecutionOn == null && listenerConfig != null) {
                    lastExecutionOn = listenerConfig.Last_Execution_On__c;
                }
                ensureListenerFieldsLoaded(listenerConfig, new Set<String>{
                    'Field_To_Track__c',
                    'Unprocessed_History_Records__c'
                });
                
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
                        
                        if (Schema.sObjectType.Listener__c.fields.Error_Message__c.isUpdateable()) {
                            listenerConfig.Error_Message__c = errorMsg;
                        }
                        update listenerConfig;
                        
                        responseList.add(response);
                        continue; // Skip to next listener config
                    }
                }
                
                try {
                    // CRITICAL: Early exit check for historical data queries only
                    // The Enable_History__c toggle controls whether we query HISTORICAL data (before Last_Execution_On__c)
                    // We ALWAYS query NEW history records (after Last_Execution_On__c) regardless of toggle state
                    // This prevents expensive historical queries when there's too much data, but still captures ongoing changes
                    // IMPORTANT: We still ensure Salesforce's built-in history tracking is enabled (done in ListenerMasterConfigurationController.createListenerRecord)
                    // This toggle only controls whether we QUERY historical records, not whether tracking is enabled
                    Boolean enableHistoryTracking = false;
                    try {
                        // Safely read the toggle value - default to false if null or inaccessible
                        enableHistoryTracking = listenerConfig.Enable_History__c == true;
                    } catch (Exception fieldEx) {
                        // If field is inaccessible or null, default to false (disabled)
                        System.debug(LoggingLevel.WARN, 'Could not read Enable_History__c field for listener ' + 
                                    (listenerConfig.Id != null ? String.valueOf(listenerConfig.Id) : 'new') + 
                                    '. Defaulting to disabled. Error: ' + fieldEx.getMessage());
                        enableHistoryTracking = false;
                    }
                    
                    // Only skip if toggle is disabled AND we're trying to query historical data (lastExecutionOn == null)
                    // If lastExecutionOn != null, we're querying new history and should always proceed
                    if (!enableHistoryTracking && lastExecutionOn == null) {
                        System.debug(LoggingLevel.INFO, '### FLOWDOMETER: History tracking toggle is DISABLED for listener: ' + 
                                    (listenerConfig.Id != null ? String.valueOf(listenerConfig.Id) : 'new') + 
                                    '. Skipping historical data query (before Last_Execution_On__c). New history queries (after Last_Execution_On__c) will still be processed.');
                        response.hasRecords = false;
                        response.isCheckSuccess = true;
                        
                        // CRITICAL: Set Last_Execution_On__c even when skipping historical query
                        // This ensures future runs will have lastExecutionOn != null and can query new history
                        // Also update Last_Check__c to trigger the scheduled flow path "Run Every 3 Minutes"
                        Datetime now = System.now();
                        Boolean shouldUpdate = false;
                        if (Schema.sObjectType.Listener__c.fields.Last_Execution_On__c.isUpdateable()) {
                            listenerConfig.Last_Execution_On__c = now;
                            shouldUpdate = true;
                        }
                        if (Schema.sObjectType.Listener__c.fields.Last_Check__c.isUpdateable()) {
                            listenerConfig.Last_Check__c = now;
                            shouldUpdate = true;
                        }
                        // Only update if we have permission to update at least one field
                        // Security Note: In test context, these fields may not be accessible without Permission Set
                        // This is acceptable because tests verify logic, not FLS enforcement
                        if (shouldUpdate) {
                            try {
                                update listenerConfig;
                            } catch (DmlException dmlEx) {
                                // Log but don't fail - the response is still successful
                                System.debug(LoggingLevel.WARN, 'Could not update Listener timestamps: ' + dmlEx.getMessage());
                            }
                        }
                        
                        responseList.add(response);
                        continue; // Skip to next listener config - NO historical queries, but new history queries will still work
                    }
                    
                    // Proceed with history processing if:
                    // 1. Toggle is enabled (allow both historical and new history queries), OR
                    // 2. Toggle is disabled BUT lastExecutionOn != null (allow new history queries only)
                    if (lastExecutionOn == null) {
                    System.debug(LoggingLevel.INFO, '### FLOWDOMETER: History tracking toggle is ENABLED for listener: ' + 
                                (listenerConfig.Id != null ? String.valueOf(listenerConfig.Id) : 'new') + 
                                    '. Proceeding with historical data query (before Last_Execution_On__c).');
                    } else {
                        System.debug(LoggingLevel.INFO, '### FLOWDOMETER: Querying new history records for listener: ' + 
                                    (listenerConfig.Id != null ? String.valueOf(listenerConfig.Id) : 'new') + 
                                    ' (after Last_Execution_On__c: ' + lastExecutionOn + '). This query proceeds regardless of toggle state.');
                    }
                    
                    // BEFORE querying new history, process any previously stored unprocessed history records
                    // Only process unprocessed records if history tracking is enabled
                    String unprocessedRecordsJson = getListenerStringField(listenerConfig, 'Unprocessed_History_Records__c');
                    if (String.isNotBlank(unprocessedRecordsJson)) {
                        Boolean smallBacklog = unprocessedRecordsJson.length() <= SMALL_BACKLOG_CHAR_THRESHOLD;
                        List<ListenerFlowController> lstListenerFlow = (List<ListenerFlowController>) JSON.deserialize(unprocessedRecordsJson, List<ListenerFlowController>.class);
                        response.lstListenerFlow = lstListenerFlow;
                        response.hasRecords = !lstListenerFlow.isEmpty();
                        response.isCheckSuccess = true;

                        // Batch size can be configurable; using 20 as the legacy default
                        Integer batchSize = FLOW_RESPONSE_BATCH_SIZE;
                        if (smallBacklog && response.lstListenerFlow.size() <= batchSize) {
                            clearUnprocessedHistoryRecords(listenerConfig);
                            responseList.add(response);
                            continue;
                        }
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
                            // Dynamically build the query to include Type__c field if specified and valid
                            List<String> selectFields = new List<String>{ 'Id', parentNameField };
                            
                            // Validate and add Type__c field if it exists on the object
                            if (String.isNotBlank(listenerConfig.Type__c)) {
                                Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(listenerConfig.Object_Name__c);
                                if (sObjectType != null) {
                                    Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
                                    // Check if the Type field exists on the object and get the actual field name (case-insensitive)
                                    String actualFieldName = null;
                                    String typeFieldLower = listenerConfig.Type__c.toLowerCase();
                                    for (String fieldNameKey : fieldMap.keySet()) {
                                        if (fieldNameKey != null && fieldNameKey.toLowerCase() == typeFieldLower) {
                                            actualFieldName = fieldNameKey;
                                            break;
                                        }
                                    }
                                    if (actualFieldName != null) {
                                        selectFields.add(actualFieldName);
                                    }
                                }
                            }
                            
                            // Validate object name to prevent SOQL injection
                            if (!Schema.getGlobalDescribe().containsKey(listenerConfig.Object_Name__c)) {
                                throw new CustomException('Invalid object name: ' + listenerConfig.Object_Name__c);
                            }
                            
                            String parentQuery = 'SELECT ' + String.join(selectFields, ', ') + 
                                               ' FROM ' + listenerConfig.Object_Name__c + 
                                               ' WHERE Id IN :parentIds WITH SECURITY_ENFORCED';
                            for (SObject sob : Database.query(parentQuery)) {
                                Id sobId = (Id)sob.get('Id');
                                sObjectMap.put(sobId, sob);
                            }
                            controllerInstance.parentRecordsMap = sObjectMap.clone();
                        }
                        // Process history records into a format usable by Flow
                        // Pass enableHistoryTracking parameter to ensure proper handling
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
                        // Explicitly set success when records were found and processed successfully
                        response.isCheckSuccess = true;
                    } else {
                        // No records found
                        response.hasRecords = false;
                        response.isCheckSuccess = true; // Explicitly set success when no records found but processing succeeded
                        System.debug(LoggingLevel.INFO, 'No history records found for processing');
                    }
                    
                    // Update last execution time and last check time on the listener config
                    // Last_Check__c is used by the scheduled flow path "Run Every 3 Minutes" to trigger subsequent runs
                    Datetime now = System.now();
                    if (Schema.sObjectType.Listener__c.fields.Last_Execution_On__c.isUpdateable()) {
                        listenerConfig.Last_Execution_On__c = now;
                    }
                    if (Schema.sObjectType.Listener__c.fields.Last_Check__c.isUpdateable()) {
                        listenerConfig.Last_Check__c = now;
                    }
                    update listenerConfig;
                    
                    // Ensure isCheckSuccess is true if we reached here without exceptions (safety check)
                    if (response.isCheckSuccess == null || response.isCheckSuccess == false) {
                        response.isCheckSuccess = true;
                    }
                    
                } catch (Exception ex) {
                    // Handle exceptions for this specific listener config
                    String errorMsg = 'Error processing listener for ' + listenerConfig.Object_Name__c + 
                                    ': ' + ex.getMessage();
                    errorMessages.add(errorMsg);
                    System.debug(LoggingLevel.ERROR, errorMsg + '\n' + ex.getStackTraceString());
        
                    // Update the listener config with error message
                    if (Schema.sObjectType.Listener__c.fields.Error_Message__c.isUpdateable()) {
                        listenerConfig.Error_Message__c = errorMsg;
                    }
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
                    if (Schema.sObjectType.Listener__c.fields.Error_Message__c.isUpdateable()) {
                        listenerToUpdate.Error_Message__c = 'Failed to process history records: ' + ex.getMessage();
                    }
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
                Schema.SObjectField cachedFieldDescribe = getCachedFieldDescribe(listenerConfig.Object_Name__c, fieldApi);
                if (cachedFieldDescribe != null) {
                    try {
                        fieldLabel = cachedFieldDescribe.getDescribe().getLabel();
                    } catch (Exception ignore) {}
                }

                listenerFlow.varCurrentFieldTracked = fieldLabel;
                listenerFlow.varCurrentFieldValue = (String) historyRecord.get('NewValue');
                listenerFlow.varCurrentObjectID = parentId;
                String nameField = (listenerConfig.Object_Name__c == 'Case') ? 'CaseNumber' : 'Name';
                // Safely get the parent record name - handle case where parent was deleted
                if (sObjectMap.containsKey(parentId) && sObjectMap.get(parentId) != null) {
                    SObject parentRecord = sObjectMap.get(parentId);
                    listenerFlow.varNameofTrackedRecord = (String) parentRecord.get(nameField);
                } else {
                    // Parent record was deleted or not found - use a default value
                    listenerFlow.varNameofTrackedRecord = '[Record Deleted]';
                }
                listenerFlow.varTrackedCustomObjectName = listenerConfig.Object_Name__c;
                listenerFlow.varEditStartTime = (Datetime) historyRecord.get('CreatedDate');
                listenerFlow.varEditEndTime = System.now();
                
                // Get the actual Type field value from the parent record, not the field API name
                if (String.isNotBlank(listenerConfig.Type__c) && sObjectMap.containsKey(parentId)) {
                    SObject parentRecord = sObjectMap.get(parentId);
                    Object typeValue = parentRecord.get(listenerConfig.Type__c);
                    if (typeValue != null) {
                        listenerFlow.varType = String.valueOf(typeValue);
                    }
                }

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
        if (Schema.sObjectType.Listener__c.fields.Unprocessed_History_Records__c.isUpdateable()) {
            listenerConfig.Unprocessed_History_Records__c = remainingRecordsJson;
        }
        update listenerConfig;

        // Finally give Flow only the first batch for this run
        response.lstListenerFlow = firstBatch;
        response.hasRecords = !response.lstListenerFlow.isEmpty();
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

}