//force-app\main\default\classes\ListenerFlowControllerTest.cls (Test class of the Controller) 

@isTest
public class ListenerFlowControllerTest {
    // Class-level static variables for storing test data across methods
    static Map<Id, List<SObject>> historyRecordsMap;
    static Case parentCase;
    static List<Flowdometer__Listener__c> testListeners;
    static List<Account> testAccounts;
    static List<Contact> testContacts;
    List<Flowdometer__Listener__c> lstListenerFlow = new List<Flowdometer__Listener__c>();
    List<ListenerFlowController.ListenerFlowLatestResponse> responseList = new List<ListenerFlowController.ListenerFlowLatestResponse>();
    ListenerFlowController.ListenerFlowLatestResponse response = new ListenerFlowController.ListenerFlowLatestResponse();
    Boolean result = false;
    Boolean hasRecords = false;    

    @TestSetup 
    static void setupTestData() {
        // Initialize the response list
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = new List<ListenerFlowController.ListenerFlowLatestResponse>();
        // Add some test data to the response list
        responseList.add(new ListenerFlowController.ListenerFlowLatestResponse());
        responseList.add(new ListenerFlowController.ListenerFlowLatestResponse());
        // Assign the response list to the class-level variable
        ListenerFlowControllerTest.responseList = responseList;
        
        // Add test data to the responseList variable
        insert ListenerFlowControllerTest.responseList;
        
        // Initialize the map to store history records for Opportunities and Cases
        historyRecordsMap = new Map<Id, List<SObject>>();
    
        // -------------- Opportunity Setup --------------
        // Standard Opportunity
        Opportunity opportunity = TestDataFactory.createOpportunity('Test Opportunity', 'Prospecting', Date.today().addDays(10));
        insert opportunity;
    
        // Opportunity History Records
        List<Opportunity> oppHistoryRecords = TestDataFactory.createOpportunityHistoryRecords(2, 'stageName');
        insert oppHistoryRecords;
    
        // Add Opportunity history records to the map
        historyRecordsMap.put(opportunity.Id, new List<SObject>(oppHistoryRecords));
    
        // Opportunity for preparingResponse tests
        Opportunity opportunityForUpdate = TestDataFactory.createOpportunity('Test Opportunity For Update', 'Prospecting', Date.today().addDays(10));
        insert opportunityForUpdate;
        opportunityForUpdate.stageName = 'Qualification';
        update opportunityForUpdate;
    
        // -------------- Case Setup --------------
        // Standard Case
        parentCase = TestDataFactory.createCase('Test Case', 'New');
        insert parentCase;
    
        // Case History Records
        List<CaseHistory> caseHistoryRecords = TestDataFactory.createCaseHistoryRecords(parentCase.Id, 'Status', 2);
        insert caseHistoryRecords;
    
        // -------------- Flowdometer Listener Setup --------------
        // Standard Listener Config
        Flowdometer__Listener__c listenerConfig = TestDataFactory.createlistenerConfig(DateTime.now(), false);
    
        // Listener for preparingResponse tests (Scenario 1)
        Datetime oneHourBefore = DateTime.now().addHours(-1);
        Flowdometer__Listener__c listenerForScenario1 = TestDataFactory.createlistenerConfig(
            'Opportunity', 'stageName', 'IsWon', oneHourBefore, false
        );
    
        // Listener for getLatestHistoryValues (Scenario 2)
        Datetime tenMinutesBefore = DateTime.now().addMinutes(-10);
        Flowdometer__Listener__c listenerForScenario2 = TestDataFactory.createlistenerConfig(
            'Opportunity', 'stageName', 'IsWon', tenMinutesBefore, false
        );
    
        // Existing Listener Configs
        Flowdometer__Listener__c listenerForPreparingResponse1 = TestDataFactory.createlistenerConfig(
            'Opportunity', 'stageName', 'IsWon', DateTime.now(), false
        );
        Flowdometer__Listener__c listenerForPreparingResponse2 = TestDataFactory.createlistenerConfig(
            'Case', 'Status', 'isClosed', DateTime.now(), false
        );
    
        // Insert all Listener Config records
        insert new List<Flowdometer__Listener__c>{
            listenerConfig, 
            listenerForPreparingResponse1, 
            listenerForPreparingResponse2, 
            listenerForScenario1,
            listenerForScenario2
        };
    
        // Store the listener records for use in test methods
        testListeners = [SELECT Id, Flowdometer__Object_Name__c FROM Flowdometer__Listener__c];
    }

    // Executes the main test logic and returns the response list
    static List<ListenerFlowController.ListenerFlowLatestResponse> runTest(
        Listener__c listenerConfig, 
        Map<Id, List<SObject>> historyRecordsMap,
        Map<String, Object> queryModifiers,
        ListenerFlowController.ListenerFlowLatestResponse response,
        Map<Id, Map<String, Id>> goalStepRecsMap,
        Map<Id, SObject> sObjectMap,
        Map<Id, List<Datetime>> sortingDateTimeMap
    ) {
        if (response != null) {
            // If a response object is provided, it means we're testing preparingResponse
            Test.startTest();
            ListenerFlowController.preparingResponse(response, historyRecordsMap, listenerConfig, goalStepRecsMap, sObjectMap, sortingDateTimeMap);
            Test.stopTest();
            // No value is returned for preparingResponse scenarios

            return null; // preparingResponse doesn't return a value, so we return null here
        } else {
            // Existing logic for other tests
            ListenerFlowController.ListenerFlowLatestRequest request = new ListenerFlowController.ListenerFlowLatestRequest();
            request.listenerConfig = listenerConfig;

            Test.startTest();
            List<SObject> responseList = ListenerFlowController.parseRecordsToFlow(
                new List<ListenerFlowController.ListenerFlowLatestRequest>{request}, historyRecordsMap, queryModifiers
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

    // Test the main logic for parsing records to flow
    @isTest
    static void testParseRecordsToFlow() {
        // Create test data
        

            // Using testListeners list from setupTestData()
            Flowdometer__Listener__c listenerConfig = testListeners[0];
        
            // Initialize other required parameters
            ListenerFlowController.ListenerFlowLatestRequest request = new ListenerFlowController.ListenerFlowLatestRequest();
            request.listenerConfig = listenerConfig;
            List<ListenerFlowController.ListenerFlowLatestRequest> requestList = new List<ListenerFlowController.ListenerFlowLatestRequest>{request};
            Map<String, Object> queryModifiers = new Map<String, Object>();

        // Run the test
        Test.startTest();
        List<ListenerFlowController.ListenerFlowLatestResponse> records = ListenerFlowController.parseRecordsToFlow(responseList);
        Test.stopTest();

        update new List<Flowdometer__Listener__c>{listenerConfig};

        // Assert: Check if the response list is not null and has one element
        System.assertNotEquals(null, responseList, 'Response List should not be null');
        System.assertEquals(1, responseList.size(), 'Response List size should be 1');

    }

    // Test the logic for fetching the latest history values
    @isTest
    static void testGetLatestHistoryValues() {
        // Create test data
        Flowdometer__Listener__c listenerConfig = testListeners[1];
        listenerConfig.Flowdometer__Last_Execution_On__c = DateTime.now().addMinutes(-10);
        update listenerConfig;
        
        // Get the queryModifiers
        Map<String, Object> queryModifiers = ListenerFlowController.getQueryModifiers(listenerConfig);

        List<SObject> responseList = runTest(listenerConfig, historyRecordsMap, null, null, null, null, null);

        // Assert: Check if all history records are returned
        for (List<SObject> historyList : historyRecordsMap.values()) {
            for (SObject record : historyList) {
                Datetime createdDate = (Datetime)record.get('CreatedDate');
                System.assert(createdDate >= listenerConfig.Flowdometer__Last_Execution_On__c, 'Record date is older than Last Execution On date');
            }
        }
    }

    // Test the that our query will max out at 10k records
    @isTest
    static void testQueryResponseLimit() {
        // Create test data
        Flowdometer__Listener__c listenerConfig = testListeners[0];

        // Run the test
        List<SObject> responseList = runTest(listenerConfig, historyRecordsMap, null, null, null, null, null);
    
        // Assert: Check if only 10,000 records are returned
        assertHistoryRecords(responseList, 10000, null);
    }

    @isTest
    static void testQueryResponseSortedByCreatedDateAndMillis() {

        // Test Execution
        List<SObject> responseList = runTest(listenerConfig, historyRecordsMap, null, null, null, null, null);
    
        Map<Id, List<SObject>> historyRecords = new Map<Id, List<SObject>>();
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
        List<SObject> responseList = runTest(listenerConfig, historyRecordsMap, null, null, null, null, null);

        // Assertions
        for (List<SObject> historyList : historyRecordsMap.values()) {
            for (SObject record : historyList) {
                Datetime createdDate = (Datetime)record.get('CreatedDate');
                System.assert(createdDate >= listenerConfig.Flowdometer__Last_Execution_On__c, 'Record date is older than Last Execution On date');
            }
        }
    }

    // Test the logic for collecting all history records on the first run
    @isTest
    static void testCollectAllHistoryRecordsOnFirstRun() {
        // Create test data
        Flowdometer__Listener__c listenerConfig = testListeners[0];

        // Run the test
        List<SObject> responseList = runTest(listenerConfig, historyRecordsMap, null, null, null, null, null);

        // Assert: Check if all history records are returned
        assertHistoryRecords(responseList, 1, 'Qualification');
        Datetime threeYearsAgo = DateTime.now().addYears(-3);
        for (List<SObject> historyList : historyRecordsMap.values()) {
            for (SObject record : historyList) {
                Datetime createdDate = (Datetime)record.get('CreatedDate');
                System.assert(createdDate >= threeYearsAgo, 'Record date is older than 3 years');
            }
        }

        // Additional Assert: Check if the history record is the one we created
        ListenerFlowController.ListenerFlowLatestResponse response = responseList[0];
        System.assertEquals(historyRecord.Id, response.lstListenerFlow[0].varHistoryRecordId, 'History record ID should match');
    }

    // Test the logic for collecting all history records on the first run
    @isTest
    static void testBulkOperations() {
        Flowdometer__Listener__c listenerConfig = new Flowdometer__Listener__c();
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = runTest(listenerConfig, null, null, null, null, null, null);

        // Assert that the response list is not null and has 200 elements
        System.assertNotEquals(null, responseList, 'Response List should not be null');
        System.assertEquals(200, responseList.size(), 'Response List size should be 200');
    }

    // Test the logic for collecting all history records on the first run
    @isTest
    static void testNoHistoryRecords() {
        Flowdometer__Listener__c listenerConfig = new Flowdometer__Listener__c();
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = runTest(listenerConfig, null, null, null, null, null, null);

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

        // Test with your custom object (Flowdometer__Flow__c)
        Boolean isFlowCustom = ListenerFlowController.isCustomObject('Flowdometer__Flow__c');
        System.assertEquals(true, isFlowCustom, 'Flowdometer__Flow__c should be a custom object');

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
        Flowdometer__Listener__c listenerConfig = testListeners[2];
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

        Map<Id, List<SObject>> historyRecordsMap = ListenerFlowController.getLatestHistoryValues(targetRecords, listenerConfig);

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
        Flowdometer__Listener__c listenerConfig = new Flowdometer__Listener__c();
        listenerConfig.Flowdometer__Object_Name__c = 'Case';
        listenerConfig.Flowdometer__Field_To_Track__c = 'Status';
        listenerConfig.Flowdometer__TerminalStage__c = 'isClosed';
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

        // Create a Flowdometer__Listener__c object for listenerConfig
        Flowdometer__Listener__c listenerConfig = new Flowdometer__Listener__c(
            Flowdometer__Object_Name__c = 'Opportunity',
            Flowdometer__Field_To_Track__c = 'stageName',
            Flowdometer__TerminalStage__c = 'IsWon'
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

        // Assertions
        System.assertNotEquals(null, response.someField, 'someField should not be null.');
        result.hasRecords = !historyRecordsMap.isEmpty();

    }
}