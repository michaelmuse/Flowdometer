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

        // -------------- Case Setup --------------
        // Standard Case
        parentCase = TestDataFactory.createCase('Test Case', 'New');
    
        // Case History Records
        List<CaseHistory> caseHistoryRecords = TestDataFactory.createCaseHistoryRecords(parentCase.Id, 'Status', 2);
        insert caseHistoryRecords;

        // -------------- Flowdometer Listener Setup --------------
        // Standard Listener Config with a Last_Execution_On__c of ten minutes ago
        DateTime tenMinutesAgo = DateTime.now().addMinutes(-10); // Setting the time 10 minutes ago
        listenerConfig = TestDataFactory.createlistenerConfig(
            'Opportunity', 'stageName', 'Closed Won', tenMinutesAgo, true
        );

        // Standard First Run Listener Config
        listenerConfig = TestDataFactory.createlistenerConfig(
          'Opportunity', 'stageName', 'Closed Won', null, true
        );
        
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
        // Create an instance of ListenerFlowController
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

        // Using the sObjectMap and sortingDateTimeMap parameters directly in the code
        // If a response object is provided, it means we're testing preparingResponse
        if (response != null) {
            Test.startTest();
            controllerInstance.preparingResponse(response, listenerConfig, sObjectMap, controllerInstance);
            Test.stopTest();
            // No value is returned for preparingResponse scenarios
            return null; // preparingResponse doesn't return a value, so we return null here
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
    static void testParseRecordsToFlow() {
        // Initialize other required parameters
        Map<String, Object> additionalParams = new Map<String, Object> {
            'queryModifiers' => new Map<String, Object>(),
            'goalStepRecsMap' => new Map<String, List<Object>>(),
            'sObjectMap' => new Map<String, SObject>(),
            'sortingDateTimeMap' => new Map<Id, List<Datetime>>()
        };
        
        Listener__c queriedListenerConfig = [SELECT Id, Last_Execution_On__c, Object_Name__c, Field_To_Track__c, TerminalStage__c FROM Listener__c LIMIT 1];
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

    // @isTest
    // static void testQueryResponseSortedByCreatedDateAndMillis() {

    //     // Test Execution
    //     List<ListenerFlowController.ListenerFlowLatestResponse> responseList = runTest(listenerConfig, historyRecordsMap, null, new Map<String, Object>(), new Map<Id, SObject>(), new Map<Id, List<Datetime>>());
    
    //     // Assertion
    //     List<SObject> sortedHistoryRecords = responseList[0].historyRecords;
    //     for(Integer i = 1; i < sortedHistoryRecords.size(); i++) {
    //         Datetime prevDate = (Datetime)sortedHistoryRecords[i-1].get('CreatedDate');
    //         Datetime currDate = (Datetime)sortedHistoryRecords[i].get('CreatedDate');
    
    //         Long prevMillis = prevDate.getTime();
    //         Long currMillis = currDate.getTime();
    
    //         System.assert(currMillis >= prevMillis, 'Records are not sorted correctly');
    //     }
    // }    

    // Test the utility method for getting a non-null string
    // @isTest
    // static void testGetStringNotNull() {
    //     String value = ListenerFlowController.getStringNotNull('Hello');
    //     System.assertEquals('Hello', value);
    //     ListenerFlowControllerTest.responseList = new List<ListenerFlowController.ListenerFlowLatestResponse>();
    //     ListenerFlowControllerTest.responseList.add(new ListenerFlowController.ListenerFlowLatestResponse());
    //     ListenerFlowControllerTest.hasRecords = true;
    //     value = ListenerFlowController.getStringNotNull(null);
    //     System.assertEquals('', value);
    //     System.assertEquals(false, ListenerFlowControllerTest.hasRecords, 'hasRecords should be false');
    // }

    // @isTest
    // static void testIsCustomObject() {
    //     // Test with a standard object (Account)
    //     Boolean isAccountCustom = ListenerFlowController.isCustomObject('Account');
    //     System.assertEquals(false, isAccountCustom, 'Account should be a standard object');

    //     // Test with your custom object (Flow__c)
    //     Boolean isFlowCustom = ListenerFlowController.isCustomObject('Flow__c');
    //     System.assertEquals(true, isFlowCustom, 'Flow__c should be a custom object');

    //     // Test with a non-existent object (ThisObjectDoesNotExist__c)
    //     Boolean isNonExistentCustom = ListenerFlowController.isCustomObject('ThisObjectDoesNotExist__c');
    //     System.assertEquals(false, isNonExistentCustom, 'Non-existent object should not be a custom object');
    // }


    // ------------------------------
    // Test Methods for preparingResponse
    // ------------------------------

    // @isTest
    // static void testPreparingResponse_Scenario1() {
    //     // Create listener record with setting created date and last execution date with one hour before from now.
    //     Datetime currentTime = DateTime.now();
    //     Datetime oneHourBefore = Datetime.newInstanceGmt(
    //         currentTime.year(),
    //         currentTime.month(),
    //         currentTime.day(),
    //         currentTime.hour() - 1,
    //         currentTime.minute(),
    //         currentTime.second()
    //     );
    //     Map<String, Object> queryModifiers = new Map<String, Object>();
    //     Listener__c listenerConfig = testListeners[2];
    //     insert listenerConfig;
    //     Test.setCreatedDate(listenerConfig.id, oneHourBefore);

    //     // Populate sortingDateTimeMap for this specific test
    //     sortingDateTimeMap.put(parentCase.Id, new List<Datetime>{DateTime.now()});

    //     Opportunity opportunity = new Opportunity(
    //         Name = 'Test Opportunity',
    //         stageName = 'Prospecting',
    //         CloseDate = Date.today().addDays(10)
    //     );
    //     insert opportunity;

    //     opportunity.stageName = 'Qualification';
    //     update opportunity;

    //     Map<String, SObject> sObjectMap = new Map<String, SObject>{
    //         opportunity.Id => opportunity
    //     };

    //     Set<Id> targetRecords = new Set<Id>{opportunity.Id};

    //     Map<Id, List<SObject>> historyRecordsMap = ListenerFlowController.getLatestHistoryValues(
    //         new List<Id>{opportunity.Id}, 
    //         listenerConfig,
    //         queryModifiers
    //     );

    //     // Create a ListenerFlowLatestResponse object for the test
    //     ListenerFlowController.ListenerFlowLatestResponse response = new ListenerFlowController.ListenerFlowLatestResponse();


    //     // Create additionalParams map
    //     Map<String, Object> additionalParams = new Map<String, Object>{
    //         'queryModifiers' => queryModifiers
    //         // Add other optional parameters as needed
    //     };

    //     // Call runTest
    //     static List<ListenerFlowController.ListenerFlowLatestResponse> runTest(
    //         Listener__c listenerConfig,
    //         Map<Id, List<SObject>> historyRecordsMap,
    //         ListenerFlowController.ListenerFlowLatestResponse response,
    //         Map<String, Object> additionalParams,
    //         Map<String, SObject> sObjectMap,
    //         Map<Id, List<Datetime>> sortingDateTimeMap
    //     )

    //     // Assertions

    // }
    @isTest
    static void testPreparingResponse_Scenario1() {
        // Create listener record with setting created date and last execution date with one hour before from now.
        Datetime currentTime = DateTime.now();
        Datetime oneHourBefore = Datetime.newInstanceGmt(
            currentTime.year(),
            currentTime.month(),
            currentTime.day(),
            currentTime.hour() - 1,
            currentTime.minute(),
            currentTime.second()
        );
        Map<String, Object> queryModifiers = new Map<String, Object>();
        Listener__c listenerConfig = [SELECT Id, Last_Execution_On__c, Object_Name__c, Field_To_Track__c, TerminalStage__c FROM Listener__c LIMIT 1];
        Test.setCreatedDate(listenerConfig.id, oneHourBefore);

        // Populate sortingDateTimeMap for this specific test
        sortingDateTimeMap.put(parentCase.Id, new List<Datetime>{DateTime.now()});

        Opportunity opportunity = new Opportunity(
            Name = 'Test Opportunity',
            stageName = 'Prospecting',
            CloseDate = Date.today().addDays(10)
        );
        insert opportunity;

        opportunity.stageName = 'Qualification';
        update opportunity;
        
        // Initialize a ListenerFlowController instance
        ListenerFlowController controllerInstance = new ListenerFlowController();

        // Initialize sObjectMap for this test
        Map<String, SObject> sObjectMap = new Map<String, SObject>{
            opportunity.Id => opportunity
        };

        // Create a ListenerFlowLatestResponse object for the test
        ListenerFlowController.ListenerFlowLatestResponse response = new ListenerFlowController.ListenerFlowLatestResponse();

        // Initialize additionalParams for the test
        Map<String, Object> additionalParams = new Map<String, Object>{
            'queryModifiers' => queryModifiers
            // Add other optional parameters as needed
        };

        // Call runTest specifically to test preparingResponse
        runTest(
            listenerConfig, 
            historyRecordsMap, 
            response, 
            additionalParams, 
            sObjectMap, 
            sortingDateTimeMap
        );

        // Assertions
        // Validate that response is populated as expected
        System.assert(response.lstListenerFlow != null, 'lstListenerFlow should not be null');
        System.assert(response.lstListenerFlow.size() > 0, 'lstListenerFlow should have elements');
        System.assert(response.hasRecords, 'hasRecords should be true');
    }

    // @IsTest
    // static void testPreparingResponse_Scenario2() {
    //     // Create test data
    //     ListenerFlowLatestResponse result = new ListenerFlowController.ListenerFlowLatestResponse();
        
    //     Listener__c listenerConfig = new Listener__c();
    //     // Initialize opportunity for this test
    //     Opportunity opportunity = new Opportunity(
    //         Name = 'Test Opportunity',
    //         StageName = 'Prospecting',
    //         CloseDate = Date.today().addDays(10)
    //     );
    //     insert opportunity;
    //     listenerConfig.Object_Name__c = 'Case';
    //     listenerConfig.Field_To_Track__c = 'Status';
    //     listenerConfig.TerminalStage__c = 'isClosed';
    //     insert listenerConfig;
    //     Map<Id, Map<String, Id>> goalStepRecsMap = new Map<Id, Map<String, Id>>();
    //     Map<Id, SObject> sObjectMap = new Map<Id, SObject>();
    //     Map<Id, List<Datetime>> sortingDateTimeMap = new Map<Id, List<Datetime>>();
    //     sortingDateTimeMap.put(opportunity.Id, new List<Datetime>{DateTime.now()});

    //     // Create a case record and related history records
    //     Case parentCase = new Case(
    //         Subject = 'Test Case',
    //         Status = 'New'
    //     );
    //     insert parentCase;

    //     // Create a ListenerFlowLatestResponse object for the test
    //     ListenerFlowController.ListenerFlowLatestResponse response = new ListenerFlowController.ListenerFlowLatestResponse();

    //     // Get the queryModifiers
    //     Map<String, Object> queryModifiers = ListenerFlowController.getQueryModifiers(listenerConfig);

    //     // Call runTest
    //     List<ListenerFlowController.ListenerFlowLatestResponse> responseList = runTest(
    //         listenerConfig, 
    //         historyRecordsMap, 
    //         null,  // No response object for this test
    //         additionalParams,
    //         new Map<Id, SObject>(),
    //         new Map<Id, List<Datetime>>(),
    //         queryModifiers
    //     );

    //     // Assertions
    //     Integer expectedSize = 10;
    //     System.assertEquals(true, response.hasRecords, 'Should have records.');
    // }

    // @isTest
    // static void testPreparingResponse() {
    //     // Create test data
    //     Map<Id, Map<String, Id>> goalStepRecsMap = new Map<Id, Map<String, Id>>();
    //     Map<Id, SObject> sObjectMap = new Map<Id, SObject>();

    //     // Create a ListenerFlowLatestResponse object for testing
    //     ListenerFlowLatestResponse result = new ListenerFlowController.ListenerFlowLatestResponse();

    //     // Create a Listener__c object for listenerConfig
    //     Listener__c listenerConfig = new Listener__c(
    //         Object_Name__c = 'Opportunity',
    //         Field_To_Track__c = 'stageName',
    //         TerminalStage__c = 'IsWon'
    //     );
    //     insert listenerConfig;

    //     Opportunity opportunity = new Opportunity(
    //         Name = 'Test Opportunity',
    //         stageName = 'Prospecting',
    //         CloseDate = Date.today().addDays(10)
    //     );
    //     insert opportunity;

    //     opportunity.stageName = 'Qualification';
    //     update opportunity;

    //     // Create a Map<Id, List<sObject>> for historyRecordsMap
        

    //     // Create a sortingDateTimeMap for the test
    //     Map<Id, List<Datetime>> sortingDateTimeMap = new Map<Id, List<Datetime>>();
    //     sortingDateTimeMap.put(opportunity.Id, new List<Datetime>{DateTime.now()});

    //     // Create a ListenerFlowLatestResponse object for the test
    //     ListenerFlowController.ListenerFlowLatestResponse response = new ListenerFlowController.ListenerFlowLatestResponse();

    //     // Call runTest() specifically for preparingResponse
    //     runTest(listenerConfig, historyRecordsMap, response, additionalParams, sObjectMap, sortingDateTimeMap, queryModifiers);

    //     // Update hasRecords based on the state of historyRecordsMap
    //     response.hasRecords = !historyRecordsMap.isEmpty();

    //     // Assertions
    //     System.assertEquals(true, response.hasRecords, 'hasRecords should be true if historyRecordsMap is not empty.');

    // }
}
