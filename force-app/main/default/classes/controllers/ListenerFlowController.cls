global class ListenerFlowController {
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

    // Class for sending simplified, serialized JSON to flow without unneccesary fields
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

    //Constructor class
    public ListenerFlowController() {
        // Initialize our collection of history records and the sorting map
        this.historyRecordsMap = new Map<Id, List<SObject>>();
        this.sortingDatetimeMap = new Map<Id, List<Datetime>>();
    }
    // Class for making editable history records
    public class EditableHistory {
        public String Id { get; set; }
        public String FieldValue { get; set; }
        public String OldValue { get; set; }
        public String NewValue { get; set; }
        public Datetime CreatedDate { get; set; }
    }
    public class MockHistoryObject {
        public Datetime CreatedDate { get; set; }
        public Id Id { get; set; }

        public MockHistoryObject(Datetime CreatedDate, Id Id) {
            this.CreatedDate = CreatedDate;
            this.Id = Id;
        }
    }
    // Wrapper class to hold the result of getLatestHistoryValues
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
    // This method sorts the history records in ascending order of CreatedDate and ID, and updates the historyList parameter.
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
    // This method allows us to call sortHistoryList from a test class
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

    // This method returns a string value of the object passed in. If the object is null, it returns an empty string.
    @TestVisible
    private static String getStringNotNull(Object valueObj) {
        if (valueObj != null) {
            return String.valueOf(valueObj);
        }

        return '';
    }

    // Called by: getLatestHistoryValues
    // This method returns a boolean value of whether the object passed in is a custom object or not.
    public static Boolean isCustomObject(String objectName) {
        SObjectType sObjectType = Schema.getGlobalDescribe().get(objectName);
        if (sObjectType == null) {
            return false;
        }

        return sObjectType.getDescribe().isCustom();
    }

    // Define the object name history variable
    @TestVisible
    private static String getHistoryObjectName(String objectName) {
        // Special case: Opportunity
        if (objectName == 'Opportunity') {
            return 'OpportunityFieldHistory';
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

    // Define ListenerFlowLatestRequest
    global class ListenerFlowLatestRequest {
        @InvocableVariable
        global Listener__c listenerConfig;

        @InvocableVariable
        global Datetime lastExecutionOn;
    }

    // Define the listenerConfigList variable
    public static List<ListenerFlowLatestRequest> listenerConfigList;

    // Section where we build and call the query ------------------------------------------------------
    // ------------------------------------------------------------------------------------------------
    // This method returns a list of historical IDs we already have, to exclude from the query.
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
    // This method builds the query string based on the listener configuration and query modifiers.
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
            if (listenerConfig.Object_Name__c == 'Case') {
                selectFields.add('CaseNumber');
            } else {
                selectFields.add('Name');
            }
            selectFields.add(listenerConfig.Field_To_Track__c);
            if (listenerConfig.Type__c != null) {
                selectFields.add(listenerConfig.Type__c);
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
        String queryStr =
            'SELECT ' +
            String.join(selectFields, ', ') +
            ' FROM ' +
            tableName; //MAY NEED TO ADD BACK SPACE BEFORE FROM
        if (!whereConditions.isEmpty()) {
            queryStr += ' WHERE ' + String.join(whereConditions, ' AND ');
        }

        // Common query modifiers - Need to move to query modifiers method and sort parents by DSC, history by ASC
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
        Datetime lastExecutionOn,
        ListenerFlowController controllerInstance,
        String objHistoryName,
        String parentIdField
    ) {
        controllerInstance.sortingDatetimeMap.clear();
        String fieldValue = 'created';
        String fieldName = listenerConfig.Field_To_Track__c;
        String objectSuffix = '__c';
        Boolean isHistoryQuery = true;
        String queryStr = buildQuery(
            objHistoryName,
            parentIdField,
            targetRecordIds,
            listenerConfig,
            true,
            lastExecutionOn
        );
        System.debug('History query built: ' + queryStr);
        // Query for history records
        Map<Id, List<SObject>> historyRecordsMap = controllerInstance.historyRecordsMap;
        Datetime queryTimestamp = Datetime.now();
        // HISTORY RECORDS QUERY to populate historyRecordsMap and sortingDatetimeMap
        Integer startCpuTime = Limits.getCpuTime();
        Integer cpuTimeLimit = 9000; // 90% of the 10-second limit for synchronous transactions

        for (SObject obj : Database.query(queryStr)) {
            //Count number of iterations in this loop
            Integer count = 0;
            count = count + 1;
            System.debug('in getLatestHistoryValues, run number: ' + count);
            Limits.getCpuTime();

            // Check the CPU time at the start of each iteration
            if (Limits.getCpuTime() - startCpuTime > cpuTimeLimit) {
                // Handle the situation, e.g., by flagging records that still need processing
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
            List<Datetime> dateTimeList = controllerInstance.sortingDatetimeMap.get(
                parentId
            );
            if (dateTimeList == null) {
                dateTimeList = new List<Datetime>();
                controllerInstance.sortingDatetimeMap.put(
                    parentId,
                    dateTimeList
                );
            }
            dateTimeList.add(createdDate);
        }

        if (!historyRecordsMap.isEmpty()) {
            // Only update Last Execution On if we have history records, otherwise we'll keep querying for the same records
            listenerConfig.Flowdometer__Last_Execution_On__c = queryTimestamp;
            // Sort using sortHistoryList method
            for (Id parentId : historyRecordsMap.keySet()) {
                List<SObject> specificHistoryList = (List<SObject>) historyRecordsMap.get(
                    parentId
                );
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
                List<SObject> historyList = historyRecordsMap.get(
                    oneHistoryParentId
                );
                SObject createdHistoryRecord = historyList[0]; // Only one record exists, so taking the first

                // Fetch the current value from the parent record map
                SObject parentRecord = controllerInstance.parentRecordsMap.get(
                    oneHistoryParentId
                );
                Object currentFieldValue = parentRecord.get(fieldName);

                // Optionally, update the historyRecordsMap
                historyRecordsMap.put(
                    oneHistoryParentId,
                    new List<SObject>{ createdHistoryRecord }
                );
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
        return new HistoryValuesResult(
            controllerInstance.historyRecordsMap,
            controllerInstance.sortingDatetimeMap
        );
    }

    public void handleBatchAndUnprocessedRecords(
        ListenerFlowLatestResponse response,
        Listener__c listenerConfig,
        Integer batchSize,
        Map<Id, Boolean> processedRecordsMap
    ) {
        List<SimplifiedListenerFlowController> remainingRecords = new List<SimplifiedListenerFlowController>();
        String remainingRecordsJson;
        // Dynamically adjust batch size when less than our default
        if (response.lstListenerFlow.size() < batchSize) {
            batchSize = response.lstListenerFlow.size();
        }

        // Return batches and store the rest
        if (response.lstListenerFlow.size() > 0) {
            // 1. Batching: Create a list containing only the first 'batchSize' records
            List<ListenerFlowController> firstBatch = new List<ListenerFlowController>();
            for (Integer i = 0; i < batchSize; i++) {
                firstBatch.add(response.lstListenerFlow[i]);
                processedRecordsMap.put(
                    (Id) response.lstListenerFlow[i].varHistoryRecordId,
                    true
                );
            }

            // If we have more records than the batch size, we need to store the rest
            if (batchSize != response.lstListenerFlow.size()) {
                // 2. Storing Unprocessed Records: Create a list of leftover records
                for (
                    Integer i = batchSize;
                    i < response.lstListenerFlow.size();
                    i++
                ) {
                    System.debug('in handleBatchAndUnprocessedRecords');
                    Limits.getCpuTime();
                    SimplifiedListenerFlowController simplifiedRecord = new SimplifiedListenerFlowController();
                    ListenerFlowController originalRecord = response.lstListenerFlow[
                        i
                    ];

                    // Set up the simplified record
                    simplifiedRecord.varType = originalRecord.varType;
                    simplifiedRecord.varTrackedCustomObjectName = originalRecord.varTrackedCustomObjectName;
                    simplifiedRecord.varEditStartTime = originalRecord.varEditStartTime;
                    simplifiedRecord.varEditEndTime = originalRecord.varEditEndTime;
                    simplifiedRecord.varCurrentObjectID = originalRecord.varCurrentObjectID;
                    simplifiedRecord.varCurrentFieldTracked = originalRecord.varCurrentFieldTracked;
                    simplifiedRecord.varCurrentFieldValue = originalRecord.varCurrentFieldValue;
                    simplifiedRecord.varNameofTrackedRecord = originalRecord.varNameofTrackedRecord;
                    simplifiedRecord.varHistoryRecordId = originalRecord.varHistoryRecordId;
                    simplifiedRecord.varLastHistoryRecordId = originalRecord.varLastHistoryRecordId;

                    remainingRecords.add(simplifiedRecord);
                }
                // Serialize remaining records
                if (!remainingRecords.isEmpty()) {
                    // <-- Add this condition
                    remainingRecordsJson = JSON.serialize(remainingRecords); // <-- Add this line
                }
                Integer fieldLimit = 131072;
                // Check if serialized string is too large
                while (remainingRecordsJson.length() > fieldLimit) {
                    // Remove the oldest record (assuming the list is sorted by varEditStartTime)
                    remainingRecords.remove(0);
                    // Re-serialize
                    remainingRecordsJson = JSON.serialize(remainingRecords);
                }

                // Remove processed records from the remaining records
                // Create a new list to hold the records to keep
                List<SimplifiedListenerFlowController> recordsToKeep = new List<SimplifiedListenerFlowController>();

                // Loop through remainingRecords to find records to keep
                for (
                    SimplifiedListenerFlowController record : remainingRecords
                ) {
                    if (
                        !processedRecordsMap.containsKey(
                            record.varHistoryRecordId
                        )
                    ) {
                        recordsToKeep.add(record);
                    } else {
                        System.debug('Record to remove: ' + record); // Maybe add a checkbox on listener to say there are history records not in Unprocessed, or add this history record ID to a list on the listener to get later?
                    }
                }
                // Replace the old remainingRecords list with the new one
                remainingRecords = recordsToKeep;
            }

            // Update the response to contain only the first batch
            response.lstListenerFlow = firstBatch;
            // Clear out the unprocessed records field
            if (remainingRecords.isEmpty()) {
                listenerConfig.Flowdometer__Unprocessed_History_Records__c = null; // or ''
            } else {
                listenerConfig.Flowdometer__Unprocessed_History_Records__c = remainingRecordsJson;
            }
            // Save the updated listenerConfig
            update listenerConfig;
        }
    }

    // Called by: parseRecordsToFlow
    // This method takes in a listener flow record, a map of parent record ids and a list of history records for each parent record id,
    // a map of goal step records, and a map of parent record ids and parent records.
    // It returns a response object with a list of listener flow controller objects.
    @TestVisible
    public void preparingResponse(
        ListenerFlowLatestResponse response,
        Listener__c listenerConfig,
        Map<String, SObject> sObjectMap,
        ListenerFlowController controllerInstance
    ) {
        // Declare the Map to track processed records
        Map<Id, Boolean> processedRecordsMap = new Map<Id, Boolean>();

        // Initialize response list if null or clear it if it has old records
        if (response.lstListenerFlow == null) {
            response.lstListenerFlow = new List<ListenerFlowController>();
        }
        SObject SObj = null;
        // Loop through the history records
        for (Id parentRecId : controllerInstance.sortingDatetimeMap.keySet()) {
            Integer count = 0;

            // Loop through the history records for each parent record
            for (
                Datetime dt : controllerInstance.sortingDatetimeMap.get(
                    parentRecId
                )
            ) {
                ListenerFlowController trackFlowObj = new ListenerFlowController();
                List<SObject> listSObj = controllerInstance.historyRecordsMap.get(
                    parentRecId
                );
                SObj = listSObj[count];
                String fieldValue;
                String newValue;

                // Handle the special case for 'created' history records
                if (SObj.get('Field') == 'created') {
                    if (
                        listSObj.size() > 1 &&
                        listSObj.size() > count + 1 &&
                        listSObj[count + 1].get('Field') ==
                        listenerConfig.Field_To_Track__c
                    ) {
                        // 'Field' was 'created' and more than one history record exists
                        fieldValue = String.valueOf(
                            listSObj[count + 1].get('OldValue')
                        );
                    } else {
                        // Field was created with no other history. Fetching the current value directly from the parent object
                        fieldValue = String.valueOf(
                            sObjectMap.get(parentRecId)
                                .get(listenerConfig.Field_To_Track__c)
                        );
                        SObject parentRecord = sObjectMap.get(parentRecId);
                    }
                } else {
                    // Not 'created', get from newValue
                    fieldValue = String.valueOf(SObj.get('NewValue'));
                }

                List<Datetime> sortedDates = controllerInstance.sortingDatetimeMap.get(
                    parentRecId
                );

                // Populating trackFlowObj
                trackFlowObj.varHistoryRecordId = (Id) SObj.get('Id');
                trackFlowObj.varCurrentFieldTracked = listenerConfig.Field_To_Track__c;
                trackFlowObj.varCurrentFieldValue = fieldValue;
                trackFlowObj.varCurrentObjectID = parentRecId;
                String parentName = getParentName(
                    listenerConfig.Object_Name__c
                );
                trackFlowObj.varNameofTrackedRecord = (String) sObjectMap.get(
                        parentRecId
                    )
                    .get(parentName);
                trackFlowObj.varTrackedCustomObjectName = listenerConfig.Object_Name__c;
                trackFlowObj.varEditStartTime = dt;
                if (count < sortedDates.size() - 1) {
                    // Make sure we have a next record
                    trackFlowObj.varEditEndTime = sortedDates[count + 1];
                } else {
                    trackFlowObj.varEditEndTime = null; // No next record
                }
                if (count > 0) {
                    // Make sure we have a previous record
                    trackFlowObj.varLastHistoryRecordId = (Id) listSObj[
                            count - 1
                        ]
                        .get('Id'); // ID of the previous history record
                } else {
                    trackFlowObj.varLastHistoryRecordId = null; // No previous record
                }
                if (listenerConfig.Type__c != null) {
                    trackFlowObj.varType = String.valueOf(
                        sObjectMap.get(parentRecId).get(listenerConfig.Type__c)
                    );
                } else {
                    trackFlowObj.varType = null;
                }
                response.lstListenerFlow.add(trackFlowObj);
                count++;
            }
        }

        // Batch the data and store the rest
        Integer batchSize = 20;
        controllerInstance.handleBatchAndUnprocessedRecords(
            response,
            listenerConfig,
            batchSize,
            processedRecordsMap
        );

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
        Label='Query & Parse History Records'
        Description='Used to query History Records in Flow'
        Category='ListenerFlowController'
    )
    public static List<ListenerFlowLatestResponse> parseRecordsToFlow(
        List<ListenerFlowLatestRequest> listenerConfigList
    ) {
        //START DEBUG
        // Grab the first listenerConfig from the list
        Listener__c firstListenerConfig = listenerConfigList[0].listenerConfig;

        // Loop through each field in the Listener__c SObject
        Map<String, Schema.SObjectField> fieldMap = Listener__c.SObjectType.getDescribe()
            .fields.getMap();
        for (String fieldName : fieldMap.keySet()) {
            // Get the field value
            Object fieldValue = firstListenerConfig.get(fieldName);

            // Debug print the field name and its value
            System.debug('Field: ' + fieldName + ', Value: ' + fieldValue);
        }
        //End DEBUG

        // Create an instance of ListenerFlowController
        ListenerFlowController controllerInstance = new ListenerFlowController();
        Listener__c listenerConfig = listenerConfigList[0].listenerConfig;
        listenerConfig.Flowdometer__Last_Check__c = Datetime.now();
        String objName = listenerConfig.Object_Name__c;
        // Get the history object name based on the object name in the listener config
        String objHistoryName = getHistoryObjectName(
            listenerConfig.Object_Name__c
        );
        // Get parentIdField
        String parentName = getParentName(listenerConfig.Object_Name__c);
        String parentIdField = isCustomObject(objName)
            ? 'ParentId'
            : (objName + 'Id');
        String fieldValue = 'created';
        String fieldName = listenerConfig.Field_To_Track__c;
        Datetime lastExecutionOn = listenerConfig.Last_Execution_On__c;
        List<ListenerFlowLatestResponse> responseList = new List<ListenerFlowLatestResponse>();
        ListenerFlowLatestResponse response = new ListenerFlowLatestResponse();
        Map<Id, SObject> sObjectMapForParse = new Map<Id, SObject>();

        // Initialize a List to hold either the deserialized or queried records.
        List<ListenerFlowController> lstListenerFlow = new List<ListenerFlowController>();

        if (listenerConfigList.isEmpty()) {
            return responseList;
        }

        Integer batchSize = 20;

        // When Historical Records Exist, use them instead of querying for them
        String unprocessedRecordsJson = listenerConfig.Flowdometer__Unprocessed_History_Records__c;
        if (String.isNotBlank(unprocessedRecordsJson)) {
            lstListenerFlow = (List<ListenerFlowController>) JSON.deserialize(
                unprocessedRecordsJson,
                List<ListenerFlowController>.class
            );
            response.lstListenerFlow = lstListenerFlow;

            // Batch the data and store the rest
            controllerInstance.handleBatchAndUnprocessedRecords(
                response,
                listenerConfig,
                batchSize,
                new Map<Id, Boolean>()
            );

            response.isCheckSuccess = true;
            response.hasRecords = !lstListenerFlow.isEmpty();

            responseList.add(response);
            return responseList;
        }

        // Otherwise query for historical records
        Set<Id> targetRecords = new Set<Id>();
        List<Id> targetRecordIds = new List<Id>(targetRecords);

        Map<String, SObject> sObjectMap = new Map<String, SObject>();

        Boolean isHistoryQuery = false;

        try {
            String queryStr = buildQuery(
                objName,
                parentIdField,
                targetRecordIds,
                listenerConfig,
                isHistoryQuery,
                lastExecutionOn
            );
            System.debug('Parent query built: ' + queryStr);

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
            Map<Id, List<Datetime>> sortingDatetimeMap = historyResult.sortingDatetimeMap;
            Set<Id> oneHistoryParentIds = new Set<Id>();
            for (Id parentId : historyRecordsMap.keySet()) {
                List<SObject> tempHistoryLst = historyRecordsMap.get(parentId);
                if (tempHistoryLst.size() == 1) {
                    oneHistoryParentIds.add(parentId);
                }
            }

            controllerInstance.preparingResponse(
                response,
                listenerConfig,
                sObjectMap,
                controllerInstance
            );

            listenerConfig.Error_Message__c = '';
        } catch (Exception e) {
            response.isCheckSuccess = false;
            listenerConfig.Error_Message__c =
                'Error: ' +
                e.getMessage() +
                ' Trace: ' +
                e.getStackTraceString();
        }
        update listenerConfig;

        responseList.add(response);
        // Loop through responseList.lstListenerFlow and log the value of each item inside of it
        for (ListenerFlowController item : responseList[0].lstListenerFlow) {
        }
        System.debug(
            'responseList[0].lstListenerFlow: ' +
            responseList[0].lstListenerFlow
        );
        return responseList;
    }
}
