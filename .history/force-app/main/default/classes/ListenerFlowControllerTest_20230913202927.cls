/*
  Class: ListenerFlowControllerTest
  Path: force-app\main\default\classes\ListenerFlowControllerTest.cls
  
  Setup Methods:
  - setupTestData(): Sets up the test data. (Lines: 56-132)

  Test Methods:
  - testParseRecordsToFlow(): Tests parseRecordsToFlow(). (Lines: 201-234)
  - testGetLatestHistoryValues(): Tests getLatestHistoryValues(). (Lines: 238-269)
    - Invokes: getQueryModifiers()
  - testQueryResponseLimit(): Tests query response limit. (Lines: 272-282)
  - testQueryResponseSortedByCreatedDateAndMillis(): Tests query sorting. (Lines: 284-301)
  - testCollectHistoryRecordsSinceLastQuery(): Tests record collection since last query. (Lines: 304-318)
  - testCollectAllHistoryRecordsOnFirstRun(): Tests first-run record collection. (Lines: 321-338)
  - testBulkOperations(): Tests bulk operations. (Lines: 341-354)
  - testNoHistoryRecords(): Tests no-history scenario. (Lines: 357-371)

  Utility Test Methods:
  - testGetStringNotNull(): Tests getStringNotNull(). (Lines: 374-384)
    - Invokes: getStringNotNull()
  - testIsCustomObject(): Tests isCustomObject(). (Lines: 386-399)
    - Invokes: isCustomObject()

  Scenario-based Tests:
  - testPreparingResponse_Scenario1(): Tests preparingResponse() in a specific scenario. (Lines: 406-456)
    - Invokes: getLatestHistoryValues()
  - testPreparingResponse_Scenario2(): Another scenario test for preparingResponse(). (Lines: 458-492)
  - testPreparingResponse(): General test for preparingResponse(). (Lines: 494-543)
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
    static Boolean result = false;
    static Boolean hasRecords = false;
    static YourType historyRecord; // Replace 'YourType' with the actual type
    static List<YourType> historyRecords = new List<YourType>();
    static YourType result; // Replace 'YourType' with the actual type
    static List<YourType> someList = new List<YourType>();
    static String someField;
    static String someOtherField;

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
        insert opportunity;
    
        // Opportunity for preparingResponse tests
        Opportunity opportunityForUpdate = TestDataFactory.createOpportunity('Test Opportunity For Update', 'Prospecting', Date.today().addDays(10));
        insert opportunityForUpdate;
        opportunityForUpdate.stageName = 'Qualification';
        update opportunityForUpdate;
    
        // Opportunity History Records
        List<Opportunity> oppHistoryRecords = TestDataFactory.createOpportunityHistoryRecords(2, 'stageName');
        insert oppHistoryRecords;

        // Opportunity History Records for preparingResponse tests
        List<SObject> oppHistoryRecordsSObject = new List<SObject>();
        for(Opportunity opp : oppHistoryRecords) {
            oppHistoryRecordsSObject.add((SObject)opp);
        }
        historyRecordsMap.put(opportunity.Id, oppHistoryRecordsSObject);

        // -------------- Case Setup --------------
        // Standard Case
        parentCase = TestDataFactory.createCase('Test Case', 'New');
        insert parentCase;
    
        // Case History Records
        List<CaseHistory> caseHistoryRecords = TestDataFactory.createCaseHistoryRecords(parentCase.Id, 'Status', 2);
        insert caseHistoryRecords;

        // -------------- Flowdometer Listener Setup --------------
        // Standard Listener Config
        listenerConfig = TestDataFactory.createlistenerConfig(
            'Opportunity', 'stageName', 'Closed Won', DateTime.now(), true
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
    
        // Insert all Listener Config records
        insert new List<Listener__c>{
            listenerConfig, 
            listenerForPreparingResponse1, 
            listenerForPreparingResponse2, 
            listenerForScenario1,
            listenerForScenario2
        };
    
        // Store the listener records for use in test methods
        testListeners = [SELECT Id, Object_Name__c FROM Listener__c];
    }

    // Executes the main test logic and returns the response list
    // Optional parameters are Map<String, Object> additionalParams
    static List<ListenerFlowController.ListenerFlowLatestResponse> runTest(
        Listener__c listenerConfig,
        Map<Id, List<SObject>> historyRecordsMap,
        Flowdometer.ListenerFlowController.ListenerFlowLatestResponse response,
        Map<String, Object> additionalParams,
        Map<Id, SObject> sObjectMap,
        Map<Id, List<Datetime>> sortingDateTimeMap
    ) {
        // Handle the default value for additionalParams inside the method
        if(additionalParams == null) {
            additionalParams = new Map<String, Object>();
        }

        // Extract optional parameters; no need to check for additionalParams != null anymore
        Map<String, Object> queryModifiers = (additionalParams.containsKey('queryModifiers')) 
                                            ? (Map<String, Object>) additionalParams.get('queryModifiers') 
                                            : new Map<String, Object>();

        Map<Id, Map<String, Id>> goalStepRecsMap = (additionalParams.containsKey('goalStepRecsMap')) 
                                                ? (Map<Id, Map<String, Id>>) additionalParams.get('goalStepRecsMap') 
                                                : new Map<Id, Map<String, Id>>();

        // Using the sObjectMap and sortingDateTimeMap parameters directly in the code
        if (response != null) {
            // If a response object is provided, it means we're testing preparingResponse
            Test.startTest();
            ListenerFlowController.preparingResponse(response, historyRecordsMap, listenerConfig, goalStepRecsMap, sObjectMap, sortingDateTimeMap);
            Test.stopTest();
            // No value is returned for preparingResponse scenarios
            return null; // preparingResponse doesn't return a value, so we return null here
        } else {
            // Handles logic for scenarios other than preparingResponse
            ListenerFlowController.ListenerFlowLatestRequest request = new ListenerFlowController.ListenerFlowLatestRequest();
            request.listenerConfig = listenerConfig;

            Test.startTest();
            List<ListenerFlowController.ListenerFlowLatestResponse> responseList = ListenerFlowController.parseRecordsToFlow(
                new List<ListenerFlowController.ListenerFlowLatestRequest>{request}
            );
            Test.stopTest();
            
            return responseList;
        }
    }

    // Validates the history records in the response list
    static void assertHistoryRecords(List<ListenerFlowController.ListenerFlowLatestResponse> responseList, Integer expectedCount, String expectedNewValue) {
        System.assertEquals(expectedCount, responseList.size(), 'The expected count of history records does not match.');
        if (expectedNewValue != null) {
            // Assuming the response includes lstListenerFlow, change responseList[0] to responseList[0].lstListenerFlow[0]
            // Checking only the first element for the current test scenario
            ListenerFlowController listenerFlowController = responseList[0].lstListenerFlow[0];
            System.assertEquals(expectedNewValue, listenerFlowController.varCurrentFieldValue, 'Latest history record does not match expected value');
        }
    }

    // ------------------------------
    // Test Methods
    // ------------------------------

    @isTest
    static void testParseRecordsToFlow() {
        // Initialize other required parameters
        Map<String, Object> queryModifiers = new Map<String, Object>();
        ListenerFlowController.ListenerFlowLatestResponse response = null;  // No response object for this test
        Map<Id, Map<String, Id>> goalStepRecsMap = new Map<Id, Map<String, Id>>();
        Map<Id, SObject> sObjectMap = new Map<Id, SObject>();
        Map<Id, List<Datetime>> sortingDateTimeMap = new Map<Id, List<Datetime>>();
        // Create a Map for additional parameters
        Map<String, Object> additionalParams = new Map<String, Object>{
            'queryModifiers' => queryModifiers,
            'goalStepRecsMap' => goalStepRecsMap,
            'sObjectMap' => sObjectMap,
            'sortingDateTimeMap' => sortingDateTimeMap
        };
        
        // Run the test using the utility method
        Test.startTest();
        List<ListenerFlowController.ListenerFlowLatestResponse> records = runTest(
            listenerConfig, 
            historyRecordsMap, 
            null,  // No response object for this test
            additionalParams
        );
        Test.stopTest();
    
        // Update listener configurations if needed
        update new List<Listener__c>{listenerConfig};
    
        // Assert: Check if the response list is not null and has one element
        System.assertNotEquals(null, records, 'Response List should not be null');
        System.assertEquals(1, records.size(), 'Response List size should be 1');
    
        // Changed the getClass() check to use instanceof
        System.assertEquals(true, (records[0] instanceof ListenerFlowController.ListenerFlowLatestResponse), 'Response should be of type ListenerFlowLatestResponse');
    }    

    // Test the logic for fetching the latest history values
    @isTest
    static void testGetLatestHistoryValues() {
        // Create test data
        Listener__c listenerConfig = testListeners[1];
        listenerConfig.Last_Execution_On__c = DateTime.now().addMinutes(-10);
        update listenerConfig;
        
        // Get the queryModifiers
        Map<String, Object> queryModifiers = ListenerFlowController.getQueryModifiers(listenerConfig);

        // Create additionalParams map
        Map<String, Object> additionalParams = new Map<String, Object>{
            'queryModifiers' => queryModifiers
            // Add other optional parameters as needed
        };

        // Update the runTest call
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = runTest(
            listenerConfig, 
            historyRecordsMap, 
            null,  // No response object for this test
            additionalParams
        );

        // Assert: Check if all history records are returned
        for (List<SObject> historyList : historyRecordsMap.values()) {
            for (SObject record : historyList) {
                Datetime createdDate = (Datetime)record.get('CreatedDate');
                System.assert(createdDate >= listenerConfig.Last_Execution_On__c, 'Record date is older than Last Execution On date');
            }
        }
    }

    // Test the that our query will max out at 10k records
    @isTest
    static void testQueryResponseLimit() {
        // Create test data
        Listener__c listenerConfig = testListeners[0];

        // Run the test
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = runTest(listenerConfig, historyRecordsMap, null, null);
    
        // Assert: Check if only 10,000 records are returned
        assertHistoryRecords(responseList, 10000, null);
    }

    @isTest
    static void testQueryResponseSortedByCreatedDateAndMillis() {

        // Test Execution
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = runTest(listenerConfig, historyRecordsMap, null, null);
    
        // Assertion
        List<SObject> sortedHistoryRecords = responseList[0].historyRecords;
        for(Integer i = 1; i < sortedHistoryRecords.size(); i++) {
            Datetime prevDate = (Datetime)sortedHistoryRecords[i-1].get('CreatedDate');
            Datetime currDate = (Datetime)sortedHistoryRecords[i].get('CreatedDate');
    
            Long prevMillis = prevDate.getTime();
            Long currMillis = currDate.getTime();
    
            System.assert(currMillis >= prevMillis, 'Records are not sorted correctly');
        }
    }    

    // Test the logic for collecting history records since the last query
    @isTest
    static void testCollectHistoryRecordsSinceLastQuery() {
        // Create test data

        // Run the test
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = runTest(listenerConfig, historyRecordsMap, null, null);

        // Assertions
        for (List<SObject> historyList : historyRecordsMap.values()) {
            for (SObject record : historyList) {
                Datetime createdDate = (Datetime)record.get('CreatedDate');
                System.assert(createdDate >= listenerConfig.Last_Execution_On__c, 'Record date is older than Last Execution On date');
            }
        }
    }

    // Test the logic for collecting all history records on the first run
    @isTest
    static void testCollectAllHistoryRecordsOnFirstRun() {
        // Create test data
        Listener__c listenerConfig = testListeners[0];

        // Run the test
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = runTest(listenerConfig, historyRecordsMap, null, null);

        // Assert: Check if all history records are returned
        assertHistoryRecords(responseList, 1, 'Qualification');
        Datetime threeYearsAgo = DateTime.now().addYears(-3);
        for (List<SObject> historyList : historyRecordsMap.values()) {
            for (SObject record : historyList) {
                Datetime createdDate = (Datetime)record.get('CreatedDate');
                System.assert(createdDate >= threeYearsAgo, 'Record date is older than 3 years');
            }
        }
    }

    // Test the logic for collecting all history records on the first run
    @isTest
    static void testBulkOperations() {
        Listener__c listenerConfig = new Listener__c();
        List<SObject> tempResponseList = runTest(listenerConfig, null, null, null);
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = 
            new List<ListenerFlowController.ListenerFlowLatestResponse>();
        for (SObject sobj : tempResponseList) {
            responseList.add((ListenerFlowController.ListenerFlowLatestResponse)sobj);
        }

        // Assert that the response list is not null and has 200 elements
        System.assertNotEquals(null, responseList, 'Response List should not be null');
        System.assertEquals(200, responseList.size(), 'Response List size should be 200');
    }

    // Test the logic for collecting all history records on the first run
    @isTest
    static void testNoHistoryRecords() {
        Listener__c listenerConfig = new Listener__c();
        List<SObject> tempResponseList = runTest(listenerConfig, null, null, null);
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = 
            new List<ListenerFlowController.ListenerFlowLatestResponse>();
        for (SObject sobj : tempResponseList) {
            responseList.add((ListenerFlowController.ListenerFlowLatestResponse)sobj);
}

        // Assert
        System.assertNotEquals(null, responseList, 'The responses should not be null.');
        System.assertEquals(1, responseList.size(), 'The size of the responses should be 1.');
        System.assertEquals(false, responseList[0].hasRecords, 'The hasRecords should be false.');
    }

    // Test the utility method for getting a non-null string
    @isTest
    static void testGetStringNotNull() {
        String value = ListenerFlowController.getStringNotNull('Hello');
        System.assertEquals('Hello', value);
        ListenerFlowControllerTest.responseList = new List<ListenerFlowController.ListenerFlowLatestResponse>();
        ListenerFlowControllerTest.responseList.add(new ListenerFlowController.ListenerFlowLatestResponse());
        ListenerFlowControllerTest.hasRecords = true;
        value = ListenerFlowController.getStringNotNull(null);
        System.assertEquals('', value);
        System.assertEquals(false, ListenerFlowControllerTest.hasRecords, 'hasRecords should be false');
    }

    @isTest
    static void testIsCustomObject() {
        // Test with a standard object (Account)
        Boolean isAccountCustom = ListenerFlowController.isCustomObject('Account');
        System.assertEquals(false, isAccountCustom, 'Account should be a standard object');

        // Test with your custom object (Flow__c)
        Boolean isFlowCustom = ListenerFlowController.isCustomObject('Flow__c');
        System.assertEquals(true, isFlowCustom, 'Flow__c should be a custom object');

        // Test with a non-existent object (ThisObjectDoesNotExist__c)
        Boolean isNonExistentCustom = ListenerFlowController.isCustomObject('ThisObjectDoesNotExist__c');
        System.assertEquals(false, isNonExistentCustom, 'Non-existent object should not be a custom object');
    }


    // ------------------------------
    // Test Methods for preparingResponse
    // ------------------------------

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
        Listener__c listenerConfig = testListeners[2];
        insert listenerConfig;
        Test.setCreatedDate(listenerConfig.id, oneHourBefore);

        // Create a sortingDateTimeMap for the test
        Map<Id, List<Datetime>> sortingDateTimeMap = new Map<Id, List<Datetime>>();
        sortingDateTimeMap.put(parentCase.Id, new List<Datetime>{DateTime.now()});

        Opportunity opportunity = new Opportunity(
            Name = 'Test Opportunity',
            stageName = 'Prospecting',
            CloseDate = Date.today().addDays(10)
        );
        insert opportunity;

        opportunity.stageName = 'Qualification';
        update opportunity;

        Map<String, SObject> sObjectMap = new Map<String, SObject>{
            opportunity.Id => opportunity
        };

        Set<Id> targetRecords = new Set<Id>{opportunity.Id};

        Map<Id, List<SObject>> historyRecordsMap = ListenerFlowController.getLatestHistoryValues(
            new List<Id>{opportunity.Id}, 
            listenerConfig, 
            queryModifiers
        );

        // Create a ListenerFlowLatestResponse object for the test
        ListenerFlowController.ListenerFlowLatestResponse response = new ListenerFlowController.ListenerFlowLatestResponse();
        String someField = 'stageName';
        String someOtherField = 'Status';
        String expectedValue = 'Status';

        // Call runTest() specifically for preparingResponse
        runTest(listenerConfig, historyRecordsMap, null, response, null, sObjectMap, sortingDateTimeMap);

        // Assertions
        System.assertNotEquals(null, response.someField, 'someField should not be null.');
        System.assertEquals('expectedValue', response.someOtherField, 'Mismatch in someOtherField.');
    }

    @IsTest
    static void testPreparingResponse_Scenario2() {
        // Create test data
        ListenerFlowLatestResponse result = new ListenerFlowController.ListenerFlowLatestResponse();
        Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
        Listener__c listenerConfig = new Listener__c();
        listenerConfig.Object_Name__c = 'Case';
        listenerConfig.Field_To_Track__c = 'Status';
        listenerConfig.TerminalStage__c = 'isClosed';
        insert listenerConfig;
        Map<Id, Map<String, Id>> goalStepRecsMap = new Map<Id, Map<String, Id>>();
        Map<Id, SObject> sObjectMap = new Map<Id, SObject>();
        Map<Id, List<Datetime>> sortingDateTimeMap = new Map<Id, List<Datetime>>();
        sortingDateTimeMap.put(opportunity.Id, new List<Datetime>{DateTime.now()});

        // Create a case record and related history records
        Case parentCase = new Case(
            Subject = 'Test Case',
            Status = 'New'
        );
        insert parentCase;



        // Create a ListenerFlowLatestResponse object for the test
        ListenerFlowController.ListenerFlowLatestResponse response = new ListenerFlowController.ListenerFlowLatestResponse();

        // Call runTest() specifically for preparingResponse
        runTest(listenerConfig, historyRecordsMap, null, response, null, sObjectMap, sortingDateTimeMap);

        // Assertions
        Integer expectedSize = 10;
        System.assertEquals(true, result.hasRecords, 'Should have records.');
        System.assertEquals(expectedSize, result.someList.size(), 'Mismatch in list size.');
    }

    @isTest
    static void testPreparingResponse() {
        // Create test data
        Map<Id, Map<String, Id>> goalStepRecsMap = new Map<Id, Map<String, Id>>();
        Map<Id, SObject> sObjectMap = new Map<Id, SObject>();

        // Create a ListenerFlowLatestResponse object for testing
        ListenerFlowLatestResponse result = new ListenerFlowController.ListenerFlowLatestResponse();

        // Create a Listener__c object for listenerConfig
        Listener__c listenerConfig = new Listener__c(
            Object_Name__c = 'Opportunity',
            Field_To_Track__c = 'stageName',
            TerminalStage__c = 'IsWon'
        );
        insert listenerConfig;

        Opportunity opportunity = new Opportunity(
            Name = 'Test Opportunity',
            stageName = 'Prospecting',
            CloseDate = Date.today().addDays(10)
        );
        insert opportunity;

        opportunity.stageName = 'Qualification';
        update opportunity;

        // Create a Map<Id, List<sObject>> for historyRecordsMap
        Map<Id, List<sObject>> historyRecordsMap = new Map<Id, List<sObject>>();

        // Create a sortingDateTimeMap for the test
        Map<Id, List<Datetime>> sortingDateTimeMap = new Map<Id, List<Datetime>>();
        sortingDateTimeMap.put(opportunity.Id, new List<Datetime>{DateTime.now()});

        // Create a ListenerFlowLatestResponse object for the test
        ListenerFlowController.ListenerFlowLatestResponse response = new ListenerFlowController.ListenerFlowLatestResponse();

        String someField = 'stageName';

        // Call runTest() specifically for preparingResponse
        runTest(listenerConfig, historyRecordsMap, null, response, null, sObjectMap, sortingDateTimeMap);

        // Update hasRecords based on the state of historyRecordsMap
        result.hasRecords = !historyRecordsMap.isEmpty();

        // Assertions
        System.assertNotEquals(null, response.someField, 'someField should not be null.');
        System.assertEquals(true, result.hasRecords, 'hasRecords should be true if historyRecordsMap is not empty.');

    }
}
