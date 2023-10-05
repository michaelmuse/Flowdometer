/*
  Class: ListenerFlowControllerTest
  Path: force-app\main\default\classes\ListenerFlowControllerTest.cls
  
  Setup Methods:
  - setupTestData(): Sets up the test data. (Lines: 56-132)

  Test Methods:
  - testParseRecordsToFlow(): Tests parseRecordsToFlow(). (Lines: 201-234)
    - Invokes: runTest(), parseRecordsToFlow()
  - testGetLatestHistoryValues(): Tests getLatestHistoryValues(). (Lines: 238-269)
    - Invokes: runTest(), getLatestHistoryValues(), isCustomObject(), getQueryModifiers()
  - testQueryResponseLimit(): Tests query response limit. (Lines: 272-282)
    - Invokes: runTest()
  - testQueryResponseSortedByCreatedDateAndMillis(): Tests query sorting. (Lines: 284-301)
    - Invokes: runTest()
  - testCollectHistoryRecordsSinceLastQuery(): Tests record collection since last query. (Lines: 304-318)
    - Invokes: runTest()
  - testCollectAllHistoryRecordsOnFirstRun(): Tests first-run record collection. (Lines: 321-338)
    - Invokes: runTest()
  - testBulkOperations(): Tests bulk operations. (Lines: 341-354)
    - Invokes: runTest()
  - testNoHistoryRecords(): Tests no-history scenario. (Lines: 357-371)
    - Invokes: runTest()

  Utility Test Methods:
  - testGetStringNotNull(): Tests getStringNotNull(). (Lines: 374-384)
    - Invokes: runTest(), getStringNotNull()
  - testIsCustomObject(): Tests isCustomObject(). (Lines: 386-399)
    - Invokes: runTest(), isCustomObject()

  Scenario-based Tests:
  - testPreparingResponse_Scenario1(): Tests preparingResponse() in a specific scenario. (Lines: 406-456)
    - Invokes: runTest(), preparingResponse(), getLatestHistoryValues(), getQueryModifiers()
  - testPreparingResponse_Scenario2(): Another scenario test for preparingResponse(). (Lines: 458-492)
    - Invokes: runTest(), preparingResponse()
  - testPreparingResponse(): General test for preparingResponse(). (Lines: 494-543)
    - Invokes: runTest(), preparingResponse(), getLatestHistoryValues(), getQueryModifiers()
*/

@isTest
public class ListenerFlowControllerTest {
    // Class-level static variables for storing test data across methods
    static Map<Id, List<SObject>> historyRecordsMap;
    static Map<Id, List<Datetime>> sortingDateTimeMap;
    static Listener__c listenerConfig;
    static Listener__c listenerConfigWExecution;
    static Case parentCase;
    static List<Listener__c> testListeners;
    static List<Account> testAccounts;
    static List<Contact> testContacts;
    static List<Listener__c> lstListenerFlow = new List<Listener__c>();
    static List<ListenerFlowController.ListenerFlowLatestResponse> responseList = new List<ListenerFlowController.ListenerFlowLatestResponse>();
    static ListenerFlowController.ListenerFlowLatestResponse response = new ListenerFlowController.ListenerFlowLatestResponse();
    static Boolean isSuccessful = false;
    static Boolean hasRecords = false;
    static Opportunity historyRecord;
    static List<Opportunity> historyRecords = new List<Opportunity>();
    static Opportunity result;
    static Opportunity opportunity;

    @TestSetup 
    static void setupTestData() {

        // Add some test data directly to the class-level responseList variable
        responseList.add(new ListenerFlowController.ListenerFlowLatestResponse());
        responseList.add(new ListenerFlowController.ListenerFlowLatestResponse());
                
        // Initialize the map to store history records for Opportunities and Cases
        historyRecordsMap = new Map<Id, List<SObject>>();
    
        // -------------- Opportunity Setup --------------
        // Standard Opportunity
        Opportunity opportunity = TestDataFactory.createOpportunity('Test Opportunity', 'Prospecting', Date.today().addDays(10));
    
        // Opportunity for preparingResponse tests
        Opportunity opportunityForUpdate = TestDataFactory.createOpportunity('Test Opportunity For Update', 'Prospecting', Date.today().addDays(10));
        
        opportunityForUpdate.stageName = 'Qualification';
        update opportunityForUpdate;
    
        // Opportunity History Records
        List<Opportunity> oppHistoryRecords = TestDataFactory.createOpportunityHistoryRecords(2, 'stageName');

        // Opportunity History Records for preparingResponse tests
        List<SObject> oppHistoryRecordsSObject = new List<SObject>();
        for(Opportunity opp : oppHistoryRecords) {
            oppHistoryRecordsSObject.add((SObject)opp);
        }
        historyRecordsMap.put(opportunity.Id, oppHistoryRecordsSObject);
        System.debug('After putting in map: historyRecordsMap = ' + historyRecordsMap);

        // -------------- Case Setup --------------
        // Standard Case Record
        parentCase = TestDataFactory.createCase('Test Case', 'New');
    
     // -------------- Flowdometer Listener Setup --------------
        // Standard Listener Config with a Last_Execution_On__c of ten minutes ago
        DateTime tenMinutesAgo = DateTime.now().addMinutes(-10); // Setting the time 10 minutes ago
        listenerConfigWExecution = TestDataFactory.createlistenerConfig(
            'Opportunity', 'stageName', 'Closed Won', tenMinutesAgo, true
        );
        System.debug('listenerConfigWExecution: ' + listenerConfigWExecution);

        // Standard First Run Listener Config
        listenerConfig = TestDataFactory.createlistenerConfig(
          'Opportunity', 'stageName', 'Closed Won', null, true
        );
        System.debug('listenerConfig: ' + listenerConfig);

        
        // Listener for preparingResponse tests (Scenario 1)
        Listener__c listenerForScenario1 = TestDataFactory.createlistenerConfig(
            'Opportunity', 'stageName', 'IsWon', DateTime.now().addHours(-1), true
        );

        // Listener for getLatestHistoryValues (Scenario 2)
        Listener__c listenerForScenario2 = TestDataFactory.createlistenerConfig(
            'Opportunity', 'stageName', 'IsWon', DateTime.now().addMinutes(-10), true
        );
    
        // Existing Listener Configs
        Listener__c listenerForPreparingResponse1 = TestDataFactory.createlistenerConfig(
            'Opportunity', 'stageName', 'IsWon', DateTime.now(), false
        );
        Listener__c listenerForPreparingResponse2 = TestDataFactory.createlistenerConfig(
            'Case', 'Status', 'isClosed', DateTime.now(), false
        );
    
        // // Insert all Listener Config records
        // insert new List<Listener__c>{
        //     listenerConfig, 
        //     listenerForPreparingResponse1, 
        //     listenerForPreparingResponse2, 
        //     listenerForScenario1,
        //     listenerForScenario2
        // };
    
        // Store the listener records for use in test methods
        testListeners = [SELECT Id, Object_Name__c FROM Listener__c];
        }
        public static void initializeHistoryRecordsMap() {
            // Fetch the Opportunity record and Opportunity history records
            Opportunity opp = [SELECT Id, Name, StageName, CloseDate FROM Opportunity WHERE Id = :opportunity.Id];
            // Use the Opportunity Id from historyRecordsMap to query OpportunityHistory
            List<Id> oppHistoryRecordIds = new List<Id>(historyRecordsMap.keySet());

            List<OpportunityHistory> oppHistories = [SELECT Id, StageName 
                                                    FROM OpportunityHistory 
                                                    WHERE OpportunityId IN :oppHistoryRecordIds];
            System.debug('opp' + opp);
            System.debug('oppHistories' + oppHistories);
        
            // Cast list of OpportunityHistory to list of SObject
            List<SObject> oppHistoriesAsSObjects = new List<SObject>();
            for(OpportunityHistory oppHistory : oppHistories) {
                oppHistoriesAsSObjects.add((SObject)oppHistory);
            }
            System.debug('oppHistoriesAsSObjects' + oppHistoriesAsSObjects);
        
            // Now, populate the historyRecordsMap
            historyRecordsMap = new Map<Id, List<SObject>>();
            historyRecordsMap.put(opp.Id, oppHistoriesAsSObjects);
            System.debug('historyRecordsMap' + historyRecordsMap);
        }
    // Executes the main test logic and returns the response list
    // Optional parameters are Map<String, Object> additionalParams
    /*
     * Helper method to run tests for the ListenerFlowController class.
     *
     * @param listenerConfig The Listener__c configuration.
     * @param historyRecordsMap A map of history records.
     * @param response The response object for preparingResponse, null for other scenarios.
     * @param additionalParams Additional parameters as a map.
     * @param sObjectMap A map of SObjects.
     * @param sortingDateTimeMap A map of sorting date and time values.
     * @return List of ListenerFlowLatestResponse objects for scenarios other than preparingResponse, null for preparingResponse.
     */
    static List<ListenerFlowController.ListenerFlowLatestResponse> runTest(
        Listener__c listenerConfig,
        Map<Id, List<SObject>> historyRecordsMap,
        Flowdometer.ListenerFlowController.ListenerFlowLatestResponse response,
        Map<String, Object> additionalParams,
        Map<String, SObject> sObjectMap,
        Map<Id, List<Datetime>> sortingDateTimeMap
    ) {
        // Create an instance of ListenerFlowController to invoke the methods
        ListenerFlowController controllerInstance = new ListenerFlowController();
        System.debug('controllerInstance: ' + controllerInstance);
         
        // Handle the default value for additionalParams inside the method
        if (additionalParams == null) {
            additionalParams = new Map<String, Object>();
        }

        // Extract optional parameters; no need to check for additionalParams != null anymore
        Map<String, Object> queryModifiers = (additionalParams.containsKey('queryModifiers'))
                ? (Map<String, Object>) additionalParams.get('queryModifiers')
                : new Map<String, Object>();

        Map<Id, Map<String, Id>> goalStepRecsMap = new Map<Id, Map<String, Id>>();
        if (additionalParams.containsKey('goalStepRecsMap')) {
            Object rawData = additionalParams.get('goalStepRecsMap');
            
            if (rawData instanceof Map<Id, Map<String, Id>>) {
                goalStepRecsMap = (Map<Id, Map<String, Id>>) rawData;
            } else if (rawData instanceof Map<String, List<Object>>) {
                Map<String, List<Object>> originalMap = (Map<String, List<Object>>) rawData;
                for (String key : originalMap.keySet()) {
                    Id newKey = Id.valueOf(key);
                    Map<String, Id> newValue = new Map<String, Id>();
                    for (Object objValue : originalMap.get(key)) {
                        // Convert 'objValue' to 'Id' if needed
                        newValue.put('record', (Id)objValue);  // Using 'record' to parallel sObjectMap in the controller
                    }
                    goalStepRecsMap.put(newKey, newValue);
                }
            }
        } else {
            goalStepRecsMap = new Map<Id, Map<String, Id>>();
        }

        // Using the sObjectMap and sortingDateTimeMap parameters directly in the code below
        // If a response object is provided, we're testing preparingResponse and need to set the sObjectMap and sortingDateTimeMap
        if (response != null) {
            Test.startTest();
            controllerInstance.preparingResponse(response, listenerConfig, sObjectMap, controllerInstance);
            Test.stopTest();
            // No value is returned for preparingResponse scenarios so we return null here
            return null; // preparingResponse doesn't return a value
        } else {
            // Handles logic for scenarios other than preparingResponse
            ListenerFlowController.ListenerFlowLatestRequest request = new ListenerFlowController.ListenerFlowLatestRequest();
            request.listenerConfig = listenerConfig;

            List<ListenerFlowController.ListenerFlowLatestRequest> requests = new List<ListenerFlowController.ListenerFlowLatestRequest>();
            requests.add(request);

            Test.startTest();
            List<ListenerFlowController.ListenerFlowLatestResponse> responseList = ListenerFlowController.parseRecordsToFlow(requests);
            Test.stopTest();

            return responseList;
        }
    }
    
    // // Validates the history records in the response list
    // static void assertHistoryRecords(List<ListenerFlowController.ListenerFlowLatestResponse> responseList, Integer expectedCount, String expectedNewValue) {
    //     System.assertEquals(expectedCount, responseList.size(), 'The expected count of history records does not match.');
    //     if (expectedNewValue != null) {
    //         // Assuming the response includes lstListenerFlow, change responseList[0] to responseList[0].lstListenerFlow[0]
    //         // Checking only the first element for the current test scenario
    //         ListenerFlowController listenerFlowController = responseList[0].lstListenerFlow[0];
    //         System.assertEquals(expectedNewValue, listenerFlowController.varCurrentFieldValue, 'Latest history record does not match expected value');
    //     }
    // }

    // ------------------------------
    // Test Methods
    // ------------------------------ 
    
    @isTest
    static void testSortHistoryList() {
        // Create a list of MockHistoryObject
        List<ListenerFlowController.MockHistoryObject> mockHistoryList = new List<ListenerFlowController.MockHistoryObject>();
        for (Integer i = 0; i < 5; i++) {
            ListenerFlowController.MockHistoryObject mockRecord = new ListenerFlowController.MockHistoryObject(
                DateTime.now().addMinutes(i), // Simulating CreatedDate
                Id.valueOf('006000000' + String.valueOf(i).leftPad(6, '0')) // Dummy Id
            );

            mockHistoryList.add(mockRecord);
        }
        
        // Shuffle the list manually
        ListenerFlowController.MockHistoryObject temp = mockHistoryList[0];
        mockHistoryList[0] = mockHistoryList[4];
        mockHistoryList[4] = temp;
        
        // Create an instance of your controller
        ListenerFlowController controllerInstance = new ListenerFlowController();
        controllerInstance.sortHistoryList_Test(mockHistoryList);
        
        // Validate that the list is sorted correctly
        for (Integer i = 1; i < mockHistoryList.size(); i++) {
            DateTime prevDate = mockHistoryList[i-1].CreatedDate;
            DateTime currDate = mockHistoryList[i].CreatedDate;
            System.assert(prevDate <= currDate, 'The list is not sorted correctly');
        }
    }    

    @isTest
    static void testIsCustomObject() {
        // Test with standard object
        String standardObjectName = 'Account';
        Boolean isCustom = ListenerFlowController.isCustomObject(standardObjectName);
        System.assertEquals(false, isCustom, 'Expected false for standard object');

        // Test with custom object
        String customObjectName = 'Flowdometer__Listener__c'; // Replace with your custom object name if different
        isCustom = ListenerFlowController.isCustomObject(customObjectName);
        System.assertEquals(true, isCustom, 'Expected true for custom object');

        // Test with non-existent object
        String nonExistentObjectName = 'NonExistentObject';
        isCustom = ListenerFlowController.isCustomObject(nonExistentObjectName);
        System.assertEquals(false, isCustom, 'Expected false for non-existent object');
    }

    @isTest static void testGetHistoryObjectName() {
      // Test for special case: Opportunity
      System.assertEquals('OpportunityFieldHistory', ListenerFlowController.getHistoryObjectName('Opportunity'), 'Should return OpportunityFieldHistory for Opportunity');
  
      // Test for standard objects
      System.assertEquals('AccountHistory', ListenerFlowController.getHistoryObjectName('Account'), 'Should return AccountHistory for Account');
      System.assertEquals('ContactHistory', ListenerFlowController.getHistoryObjectName('Contact'), 'Should return ContactHistory for Contact');
      // Add more standard objects if you have them
  
      // Test for custom objects
      System.assertEquals('Flowdometer__Listener__History', ListenerFlowController.getHistoryObjectName('Flowdometer__Listener__c'), 'Should return Flowdometer__Listener__History for Flowdometer__Listener__c');
  
    }

    @isTest static void testGetParentName() {
    // Test known object types
    System.assertEquals('CaseNumber', ListenerFlowController.getParentName('Case'), 'Should return CaseNumber for Case');
    System.assertEquals('SolutionNumber', ListenerFlowController.getParentName('Solution'), 'Should return SolutionNumber for Solution');
    System.assertEquals('ContractNumber', ListenerFlowController.getParentName('Contract'), 'Should return ContractNumber for Contract');
    
    // Test an unknown standard object
    System.assertEquals('Name', ListenerFlowController.getParentName('Account'), 'Should return Name for unknown standard objects');
    
    // Test a custom object
    System.assertEquals('Name', ListenerFlowController.getParentName('CustomObject__c'), 'Should return Name for custom objects');
    }
    
    @isTest static void testGetStringNotNull() {
      // Test for null input
      System.assertEquals('', ListenerFlowController.getStringNotNull(null), 'Should return empty string for null input');
      
      // Test for non-null inputs
      System.assertEquals('42', ListenerFlowController.getStringNotNull(42), 'Should return string "42" for integer 42');
      System.assertEquals('true', ListenerFlowController.getStringNotNull(true), 'Should return string "true" for boolean true');
      System.assertEquals('some text', ListenerFlowController.getStringNotNull('some text'), 'Should return string "some text" for string input');
      // Add more data types as needed
    }

    @isTest
    static void testParseRecordsToFlow() {
        // Initialize other required parameters
        Map<String, Object> additionalParams = new Map<String, Object> {
            'queryModifiers' => new Map<String, Object>(),
            'goalStepRecsMap' => new Map<String, List<Object>>(),
            'sObjectMap' => new Map<String, SObject>(),
            'sortingDateTimeMap' => new Map<Id, List<Datetime>>()
        };
        
        Listener__c queriedListenerConfig = [SELECT Id, Last_Execution_On__c, Object_Name__c, Field_To_Track__c, TerminalStage__c, Flowdometer__Unprocessed_History_Records__c FROM Listener__c LIMIT 1];
        queriedListenerConfig.Last_Execution_On__c = null;
        // listenerConfig.Last_Execution_On__c = null;  
        // update new List<Listener__c> {listenerConfig};
    
        // Run the test using the utility method
        List<ListenerFlowController.ListenerFlowLatestResponse> records = runTest(queriedListenerConfig, historyRecordsMap, null, additionalParams, new Map<String, SObject>(), new Map<Id, List<Datetime>>());
    
        // Assert: Check if a 'created' history record has a stage name.
        if (records.size() > 0 && records[0].lstListenerFlow.size() > 0) {
        ListenerFlowController listenerFlowController = records[0].lstListenerFlow[0];
        System.assertNotEquals(null, listenerFlowController.varCurrentFieldValue, 'Stage name should not be null');
        }
    }

    @isTest
    static void testBuildQuery_Scenario1() {
        // Query for the Listener__c record where Last_Execution_On__c is null
        Listener__c queriedListenerConfig = [SELECT Id, Last_Execution_On__c, Object_Name__c, Field_To_Track__c, TerminalStage__c FROM Listener__c WHERE Last_Execution_On__c = null LIMIT 1];
        
        // Query for the Opportunity IDs to use as targetRecordIds
        List<Id> targetRecordIds = new List<Id>();
        for(Opportunity opp : [SELECT Id FROM Opportunity LIMIT 2]) {
            targetRecordIds.add(opp.Id);
        }
        
        // Determine parentIdField based on object name
        String objName = queriedListenerConfig.Object_Name__c;
        String parentIdField = (objName.endsWith('__c')) ? 'ParentId' : (objName + 'Id');
        
        DateTime lastExecutionOn = null;  // Last Execution On is blank
        Boolean isHistoryQuery = true;    // isHistoryQuery is true
        
        // Call the method to build the query
        String queryStr = ListenerFlowController.buildQuery(objName, parentIdField, targetRecordIds, queriedListenerConfig, isHistoryQuery, lastExecutionOn);
    
        // Now make assertions to ensure the query string is built correctly
        System.assert(queryStr.contains('SELECT Id, Field, OldValue, NewValue, CreatedDate, ' + parentIdField + ' FROM ' + objName), 'The SELECT clause is incorrect');
        System.assert(queryStr.contains('WHERE (Field =: fieldValue OR Field =: fieldName) AND ' + parentIdField + ' IN :targetRecordIds'), 'The WHERE clause is incorrect');
    }

    @isTest
    static void testBuildQuery_Scenario2() {
        // Fetch a Listener__c record where Last_Execution_On__c is NULL
        Listener__c queriedListenerConfig = [SELECT Id, Last_Execution_On__c, Object_Name__c, Field_To_Track__c, TerminalStage__c FROM Listener__c WHERE Last_Execution_On__c = NULL LIMIT 1];
        queriedListenerConfig.Last_Execution_On__c = null;

        // Fetch Opportunities to populate targetRecordIds
        List<Opportunity> opportunities = [SELECT Id FROM Opportunity LIMIT 2];
        List<Id> targetRecordIds = new List<Id>();
        for (Opportunity opp : opportunities) {
            targetRecordIds.add(opp.Id);
        }

        String objName = queriedListenerConfig.Object_Name__c;
        String parentIdField = (objName.endsWith('__c')) ? 'ParentId' : (objName + 'Id');
        Boolean isHistoryQuery = false;

        String actualQuery = ListenerFlowController.buildQuery(objName, parentIdField, targetRecordIds, queriedListenerConfig, isHistoryQuery, queriedListenerConfig.Last_Execution_On__c);

        // Initialize the base query
        String expectedQuery = 'SELECT Id, Name';
        // Conditionally add TerminalStage__c if it's not null
        if (queriedListenerConfig.TerminalStage__c != null) {
            expectedQuery += ', ' + queriedListenerConfig.TerminalStage__c;
        }
        // Finish constructing the query
        expectedQuery += ', ' + queriedListenerConfig.Field_To_Track__c + ' FROM Opportunity ORDER BY Id, CreatedDate ASC LIMIT 10000';

        // Assert: Check if the actual query string matches the expected one
        System.assertEquals(expectedQuery, actualQuery, 'Query does not match expected value for Scenario 2');
    }
    @isTest
    static void testBuildQuery_Scenario3() {
        // Fetch a Listener__c record; assume it exists, so no WHERE clause
        Listener__c queriedListenerConfig = [SELECT Id, Last_Execution_On__c, Object_Name__c, Field_To_Track__c, TerminalStage__c FROM Listener__c LIMIT 1];
        queriedListenerConfig.Last_Execution_On__c = DateTime.now().addMinutes(-10);  // 10 minutes before now

        // Fetch Opportunities to populate targetRecordIds
        List<Opportunity> opportunities = [SELECT Id FROM Opportunity LIMIT 2];
        List<Id> targetRecordIds = new List<Id>();
        for (Opportunity opp : opportunities) {
            targetRecordIds.add(opp.Id);
        }

        String objName = queriedListenerConfig.Object_Name__c;
        String parentIdField = (objName.endsWith('__c')) ? 'ParentId' : (objName + 'Id');
        Boolean isHistoryQuery = true;

        // Build the actual query
        String actualQuery = ListenerFlowController.buildQuery(objName, parentIdField, targetRecordIds, queriedListenerConfig, isHistoryQuery, queriedListenerConfig.Last_Execution_On__c);

        // Initialize the base query for history query
        String expectedQuery = 'SELECT Id, Field, OldValue, NewValue, CreatedDate, ' + parentIdField;
        expectedQuery += ' FROM ' + objName;
        expectedQuery += ' WHERE (Field =: fieldValue OR Field =: fieldName) AND ' + parentIdField + ' IN :targetRecordIds AND CreatedDate > :lastExecutionOn';
        expectedQuery += ' ORDER BY ' + parentIdField + ', CreatedDate ASC LIMIT 10000';

        // Assert: Check if the actual query string matches the expected one
        System.assertEquals(expectedQuery, actualQuery, 'Query does not match expected value for Scenario 3');
    }
    @isTest
    static void testBuildQuery_Scenario4() {
        // Fetch a Listener__c record; assume it exists, so no WHERE clause
        Listener__c queriedListenerConfig = [SELECT Id, Last_Execution_On__c, Object_Name__c, Field_To_Track__c, TerminalStage__c FROM Listener__c LIMIT 1];
        queriedListenerConfig.Last_Execution_On__c = DateTime.now().addMinutes(-10);  // 10 minutes before now

        // Fetch Opportunities to populate targetRecordIds
        List<Opportunity> opportunities = [SELECT Id FROM Opportunity LIMIT 2];
        List<Id> targetRecordIds = new List<Id>();
        for (Opportunity opp : opportunities) {
            targetRecordIds.add(opp.Id);
        }

        String objName = queriedListenerConfig.Object_Name__c;
        String parentIdField = (objName.endsWith('__c')) ? 'ParentId' : (objName + 'Id');
        Boolean isHistoryQuery = false;  // Setting this to false for Scenario 4

        // Build the actual query
        String actualQuery = ListenerFlowController.buildQuery(objName, parentIdField, targetRecordIds, queriedListenerConfig, isHistoryQuery, queriedListenerConfig.Last_Execution_On__c);

        // Initialize the base query for parent record query
        String expectedQuery = 'SELECT Id, Name';
        if (queriedListenerConfig.TerminalStage__c != null) {
            expectedQuery += ', ' + queriedListenerConfig.TerminalStage__c;
        }
        expectedQuery += ', ' + queriedListenerConfig.Field_To_Track__c + ' FROM ' + objName;
        expectedQuery += ' ORDER BY Id, CreatedDate ASC LIMIT 10000';

        // Assert: Check if the actual query string matches the expected one
        System.assertEquals(expectedQuery, actualQuery, 'Query does not match expected value for Scenario 4');
    }

    @isTest
    static void testGetLatestHistoryValues() {
        // Get test data
        Listener__c queriedListenerConfig = [SELECT Id, Last_Execution_On__c, Object_Name__c, Field_To_Track__c, TerminalStage__c FROM Listener__c LIMIT 1];
        queriedListenerConfig.Last_Execution_On__c = null;
        
        // Define other missing parameters
        ListenerFlowController controllerInstance = new ListenerFlowController();
        String objName = queriedListenerConfig.Object_Name__c;
        DateTime lastExecutionOn = queriedListenerConfig.Last_Execution_On__c;
        String objHistoryName = ListenerFlowController.getHistoryObjectName(queriedListenerConfig.Object_Name__c);
        String parentIdField = ListenerFlowController.isCustomObject(objName) ? 'ParentId' : (objName + 'Id');

        // Get the queryModifiers
        Map<String, Object> queryModifiers = ListenerFlowController.getQueryModifiers(true, lastExecutionOn);

        // Call getLatestHistoryValues and store the result in a variable of type HistoryValuesResult
        ListenerFlowController.HistoryValuesResult historyValuesResult = ListenerFlowController.getLatestHistoryValues(
          new List<Id>{queriedListenerConfig.Id}, 
          queriedListenerConfig, 
          lastExecutionOn,
          controllerInstance,
          objHistoryName,
          parentIdField
        );
        System.assertNotEquals(null, historyValuesResult, 'HistoryValuesResult should not be null');

        // Access the historyRecordsMap field from the HistoryValuesResult instance
        Map<Id, List<SObject>> historyRecordsMap = historyValuesResult.historyRecordsMap;
        System.assertNotEquals(null, historyRecordsMap, 'historyRecordsMap should not be null');

        // Assert: Check if all history records are returned
        for (List<SObject> historyList : historyRecordsMap.values()) {
            for (SObject record : historyList) {
                Datetime createdDate = (Datetime)record.get('CreatedDate');
                System.assert(createdDate >= queriedListenerConfig.Last_Execution_On__c, 'Record date is older than Last Execution On date');
            }
        }
    }
}