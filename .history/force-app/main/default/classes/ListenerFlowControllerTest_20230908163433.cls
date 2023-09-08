//force-app\main\default\classes\ListenerFlowControllerTest.cls
@isTest
public class ListenerFlowControllerTest {
    // Import the TestDataFactory class
    // Assuming TestDataFactory is in the same namespace as the test class
    // You may need to adjust the namespace if it's in a different one
    // You can also use a 'seeAllData=true' annotation if required

    // Import statement
    // Add this import statement at the beginning of your test class
    // Make sure the namespace is correct
    // Example: 'import namespacePrefix.TestDataFactory;'

    TestDataFactory dataFactory = new TestDataFactory();
    // Define the TestDataFactory class
    public TestDataFactory testDataFactory;

    // Constructor logic
    // Create an instance of TestDataFactory in the constructor
    public ListenerFlowControllerTest() {
        testDataFactory = new TestDataFactory();
    }

    // Define the historyRecords and request variables
    List<OpportunityFieldHistory> historyRecords;
    ListenerFlowController.ListenerFlowLatestRequest request;

    // ------------------------------
    // Helper Methods
    // ------------------------------

    // This could be a setup method or part of a specific test method
    @TestSetup
    static void setupTestData() {
        // Initialize your TestDataFactory
        TestDataFactory testDataFactory = new TestDataFactory();
        
        // Initialize your historyRecordsMap
        Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
        
        // Call the createOpportunity method to create and insert an Opportunity record
        Opportunity opportunity = createOpportunity('Test Opp', 'Prospecting', Date.today().addDays(10));
        
        // Use TestDataFactory to create history records for Opportunity
        List<Opportunity> oppHistoryRecords = testDataFactory.createOpportunityHistoryRecords(2, 'stageName');
        historyRecordsMap.put(opportunity.Id, oppHistoryRecords);
        
        // Create and insert a Case record
        Case parentCase = new Case(Subject = 'Test Case', Status = 'New');
        insert parentCase;
        
        // Use TestDataFactory to create history records for Case
        List<CaseHistory> caseHistoryRecords = testDataFactory.createCaseHistoryRecords(2, 'Status');
        historyRecordsMap.put(parentCase.Id, new List<SObject>(caseHistoryRecords));
    }

    // ------------------------------
    // Code Snippets Using Helper Methods
    // ------------------------------

    // Add the TestDataFactory class definition
    public class TestDataFactory {
        // TestDataFactory methods here
    }

    // ------------------------------
    // Test Setup and Assertion Methods
    // ------------------------------

    // // MockQueryLocator should implement the Database.Batchable interface
    // public class MockQueryLocator implements Database.Batchable<sObject> {
    //     public Database.QueryLocator start(Database.BatchableContext bc) {
    //         return Database.getQueryLocator('SELECT Id FROM Account LIMIT 1');
    //     }
    //     public void execute(Database.BatchableContext bc, List<sObject> scope) {
    //         // Implementation here
    //     }
    //     public void finish(Database.BatchableContext bc) {
    //         // Implementation here
    //     }
    // }

    // Creates a Listener Config record for testing
    static Flowdometer__Listener__c createlistenerConfigRec(DateTime lastExecutionOn) {
        Flowdometer__Listener__c listenerConfigRec = TestDataFactory.createlistenerConfigRec(lastExecutionOn);
        insert listenerConfigRec;
        return listenerConfigRec;
    }

    // Creates an Opportunity record for testing
    static Opportunity createAndUpdateOpportunity(String newStage) {
        Opportunity opportunity = TestDataFactory.createOpportunity('Prospecting');
        insert opportunity;
        opportunity.stageName = newStage;
        update opportunity;
        return opportunity;
    }

    // Executes the main test logic and returns the response list
    static List<ListenerFlowController.ListenerFlowLatestResponse> runTest(
        Flowdometer__Listener__c listenerConfigRec, 
        Map<Id, List<SObject>> historyRecordsMap,
        Map<String, Object> queryModifiers
    ) {
        ListenerFlowController.ListenerFlowLatestRequest request = new ListenerFlowController.ListenerFlowLatestRequest();
        request.listenerConfigRec = listenerConfigRec;

        Test.startTest();
        // Call parseRecordsToFlow method with historyRecordsMap and queryModifiers
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = ListenerFlowController.parseRecordsToFlow(
            new List<ListenerFlowController.ListenerFlowLatestRequest>{request}, 
            historyRecordsMap != null ? historyRecordsMap : new Map<Id, List<SObject>>(), 
            queryModifiers != null ? queryModifiers : new Map<String, Object>()
        );
        Test.stopTest();

        return responseList;
    }

    // Validates the history records in the response list
    static void assertHistoryRecords(List<ListenerFlowController.ListenerFlowLatestResponse> responseList, Integer expectedCount, String expectedNewValue) {
        System.assertEquals(expectedCount, responseList[0].historyRecords.size(), 'The expected count of history records does not match.');
        if (expectedNewValue != null) {
            SObject latestHistoryRecord = responseList[0].historyRecords[0];
            System.assertEquals(expectedNewValue, (String)latestHistoryRecord.get('NewValue'), 'Latest history record does not match expected value');
        }
    }

    // ------------------------------
    // Test Methods
    // ------------------------------

    // Test the main logic for parsing records to flow
    @isTest
    static void testParseRecordsToFlow() {
        // Setup test data
            // Mock a history record for the Opportunity
            SObject historyRecord = new SObject();
            historyRecord.put('Id', 'some_id_here');  // Replace with appropriate Id
            historyRecord.put('NewValue', 'some_value_here');
            historyRecord.put('CreatedDate', DateTime.now());

            // Populate the historyRecordsMap
            historyRecordsMap.put('some_id_here', new List<SObject>{historyRecord});

            // Create a Listener__c record
            Listener__c listenerConfigRec = new Listener__c(
                // Initialize fields as needed
            );
            insert listenerConfigRec;

            // Create a ListenerFlowLatestRequest
            ListenerFlowLatestRequest request = new ListenerFlowLatestRequest();
            request.listenerConfigRec = listenerConfigRec;

            // Initialize other required parameters
            List<ListenerFlowLatestRequest> requestList = new List<ListenerFlowLatestRequest>{request};
            Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
            Map<String, Object> queryModifiers = new Map<String, Object>();

        // Run the test
        Test.startTest();
        List<ListenerFlowLatestResponse> responseList = parseRecordsToFlow(requestList, historyRecordsMap, queryModifiers);
        Test.stopTest();

        update new List<Listener__c>{listenerConfigRec};
        return new List<ListenerFlowLatestResponse>{response};
    }

    // Test the logic for fetching the latest history values
    @isTest
    static void testGetLatestHistoryValues() {
        // Create test data
        setupTestData();
        
        // Use TestDataFactory to create listenerConfigRec and Opportunity records
        Flowdometer__Listener__c listenerConfigRec = TestDataFactory.createlistenerConfigRec(DateTime.now());
        insert listenerConfigRec;
    
        Opportunity opportunity = TestDataFactory.createOpportunity('Test Opportunity', 'Prospecting', Date.today().addDays(10));
        insert opportunity;
    
        opportunity.stageName = 'Qualification';
        update opportunity;
    
        Set<Id> targetRecords = new Set<Id>{opportunity.Id};
    
        // Get the queryModifiers
        Map<String, Object> queryModifiers = ListenerFlowController.getQueryModifiers(listenerConfigRec);
    
        // Add this line before Test.startTest()
        listenerConfigRec.Flowdometer__Last_Execution_On__c = DateTime.now().addMinutes(-10);
        update listenerConfigRec;

        Test.startTest();
        // Call the getLatestHistoryValues method with all parameters
        Map<Id, List<SObject>> historyRecordsMap = ListenerFlowController.getLatestHistoryValues(targetRecords, listenerConfigRec, queryModifiers);
        Test.stopTest();

        for (List<SObject> historyList : historyRecordsMap.values()) {
            for (SObject record : historyList) {
                Datetime createdDate = (Datetime)record.get('CreatedDate');
                System.assert(createdDate >= listenerConfigRec.Flowdometer__Last_Execution_On__c, 'Record date is older than Last Execution On date');
            }
        }
    }

    // Test the that our query will max out at 10k records
    @isTest
    static void testQueryResponseLimit() {
        // Create test data

        // Mock a history record for the Opportunity
        SObject historyRecord = new SObject();
        historyRecord.put('Id', opportunity.Id);
        historyRecord.put('NewValue', 'Proposal');
        historyRecord.put('CreatedDate', DateTime.now());

        // Populate the historyRecordsMap
        historyRecordsMap.put(opportunity.Id, new List<SObject>{historyRecord});

        Flowdometer__Listener__c listenerConfigRec = createlistenerConfigRec(DateTime.now());
        insert listenerConfigRec;
    

        Opportunity opportunity = createAndUpdateOpportunity('Proposal');
        insert opportunity;
    
        // Create a Map to hold the history records
        Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
        historyRecordsMap.put(opportunity.Id, new List<SObject>());
    
        // Create more than 10,000 history records
        for(Integer i = 0; i < 10001; i++) {
            // Use TestDataFactory to create Opportunity history records with the provided fieldName
            List<Opportunity> oppHistoryRecords = TestDataFactory.createOpportunityHistoryRecords(1, 'updated');
            historyRecordsMap.get(opportunity.Id).addAll(oppHistoryRecords);
        }
    
        // Run the test
        Test.startTest();
        // Pass the populated historyRecordsMap
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = runTest(listenerConfigRec, historyRecordsMap);
        Test.stopTest();
    
        // Assert: Check if only 10,000 records are returned
        assertHistoryRecords(responseList, 10000);
    }

    @isTest
    static void testQueryResponseSortedByCreatedDateAndMillis() {
        // Setup
        Opportunity opportunity = createAndUpdateOpportunity('Proposal');
        insert opportunity;
    
        Flowdometer__Listener__c listenerConfigRec = createlistenerConfigRec(DateTime.now());
        insert listenerConfigRec;
    
        // Mock history records with varying milliseconds
        List<SObject> historyRecords = new List<SObject>();
        for(Long i = 0; i < 5; i++) {
            SObject historyRecord = new SObject();
            historyRecord.put('Id', opportunity.Id);
            historyRecord.put('CreatedDate', DateTime.now().addMilliseconds((Integer)i));
            historyRecords.add(historyRecord);
        }
    
        // Create a Map to hold the history records
        Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
        historyRecordsMap.put(opportunity.Id, historyRecords);
    
        // Test Execution
        Test.startTest();
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = runTest(listenerConfigRec, historyRecordsMap);
        Test.stopTest();
    
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
        Flowdometer__Listener__c listenerConfigRec = TestDataFactory.createlistenerConfigRec(DateTime.now());
        
        Opportunity opportunity = TestDataFactory.createOpportunity('Proposal');
        insert opportunity;

        // Create an empty Map to simulate no history records
        Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();

        listenerConfigRec.Flowdometer__Last_Execution_On__c = DateTime.now().addMinutes(-10);
        update listenerConfigRec;

        // Run the test
        Test.startTest();
        // Pass the empty historyRecordsMap
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = runTest(listenerConfigRec, historyRecordsMap);
        Test.stopTest();

        // Assertions
        for (List<SObject> historyList : historyRecordsMap.values()) {
            for (SObject record : historyList) {
                Datetime createdDate = (Datetime)record.get('CreatedDate');
                System.assert(createdDate >= listenerConfigRec.Flowdometer__Last_Execution_On__c, 'Record date is older than Last Execution On date');
            }
        }
    }

    // Test the logic for collecting all history records on the first run
    @isTest
    static void testCollectAllHistoryRecordsOnFirstRun() {
        Flowdometer__Listener__c listenerConfigRec = createlistenerConfigRec(null);  // Passing null to simulate first run
        Opportunity opportunity = createAndUpdateOpportunity('Qualification');
    

        // Mock a history record for the Opportunity
        SObject historyRecord = new SObject();
        historyRecord.put('Id', opportunity.Id);
        historyRecord.put('NewValue', 'Qualification');
        historyRecord.put('CreatedDate', DateTime.now());

        // Create a Map to hold the history records
        Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
        historyRecordsMap.put(opportunity.Id, new List<SObject>{historyRecord});

        listenerConfigRec.Flowdometer__Last_Execution_On__c = null;
        update listenerConfigRec;

        // Run the test
        Test.startTest();
        // Pass the populated historyRecordsMap
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = runTest(listenerConfigRec, historyRecordsMap);
        Test.stopTest();

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

    // Validates the history records in the response list for SObject "history" records
    static void assertHistoryRecords(List<ListenerFlowController.ListenerFlowLatestResponse> responseList, Integer expectedCount, String expectedNewValue) {
        System.assertEquals(expectedCount, responseList[0].historyRecords.size(), 'The expected count of history records does not match.');
        if (expectedNewValue != null) {
            SObject latestHistoryRecord = responseList[0].historyRecords[0];
            System.assertEquals(expectedNewValue, (String)latestHistoryRecord.get('NewValue'), 'Latest history record does not match expected value');
        }
    }

    @isTest
    static void testBulkOperations() {
        // Arrange
        // Use TestDataFactory to create History__c records
        List<History__c> historyRecords = TestDataFactory.createHistoryRecords(200);
        insert historyRecords;

        // Create a Listener__c record for testing
        Listener__c listenerConfigRec = new Listener__c(
            Object_Name__c = 'History__c',  // Replace with the actual object name
            Field_To_Track__c = 'Field1__c'  // Replace with the actual field name
        );
        insert listenerConfigRec;

        // Act
        Test.startTest();
        // Call getLatestHistoryValues method
        Map<String, Object> queryModifiers = ListenerFlowController.getQueryModifiers(listenerConfigRec);
        Set<Id> parentIds = new Set<Id>(); // Populate this with the parent Ids related to your History__c records
        for(History__c record : historyRecords) {
            parentIds.add(record.ParentId__c);  // Replace with the actual parent Id field
        }
        Map<Id, List<SObject>> result = ListenerFlowController.getLatestHistoryValues(parentIds, listenerConfigRec, queryModifiers);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, result, 'The result should not be null.');
        System.assertEquals(200, result.size(), 'The size of the result should be 200.');
    }

    @isTest
    static void testNoHistoryRecords() {
        // Arrange
        // Create Opportunity records using the data factory
        Opportunity testOpportunity = TestDataFactory.createOpportunity('Prospecting');
        // No need to insert here, as it's done in the factory method
    
        // Create a Listener__c record using the data factory
        Flowdometer__Listener__c listenerConfigRec = TestDataFactory.createlistenerConfigRec(DateTime.now(), true);
        // No need to insert here, as it's done in the factory method
    
        // Act
        Test.startTest();
        // Call parseRecordsToFlow method
        ListenerFlowController.ListenerFlowLatestRequest request = new ListenerFlowController.ListenerFlowLatestRequest();
        request.listenerConfigRec = listenerConfigRec;
        List<ListenerFlowController.ListenerFlowLatestResponse> responses = ListenerFlowController.parseRecordsToFlow(new List<ListenerFlowController.ListenerFlowLatestRequest>{request}, listenerConfigRec);
        Test.stopTest();
    
        // Assert
        System.assertNotEquals(null, responses, 'The responses should not be null.');
        System.assertEquals(1, responses.size(), 'The size of the responses should be 1.');
        System.assertEquals(false, responses[0].hasRecords, 'The hasRecords should be false.');
    }

    // Test the utility method for getting a non-null string
    @isTest
    static void testGetStringNotNull() {
        String value = ListenerFlowController.getStringNotNull('Hello');
        System.assertEquals('Hello', value);

        value = ListenerFlowController.getStringNotNull(null);
        System.assertEquals('', value);
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
        Flowdometer__Listener__c listenerConfigRec = new Flowdometer__Listener__c(
            Flowdometer__Object_Name__c = 'Opportunity',
            Flowdometer__Field_To_Track__c = 'stageName',
            Flowdometer__TerminalStage__c = 'IsWon',
            Flowdometer__Last_Execution_On__c = oneHourBefore
        );
        insert listenerConfigRec;
        Test.setCreatedDate(listenerConfigRec.id, oneHourBefore);

        // Create a sortingDateTimeMap for the test
        Map<Id, List<Datetime>> sortingDateTimeMap = new Map<Id, List<Datetime>>();
        sortingDateTimeMap.put(opportunity.Id, new List<Datetime>{DateTime.now()});

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

        Map<Id, List<SObject>> historyRecordsMap = ListenerFlowController.getLatestHistoryValues(targetRecords, listenerConfigRec);

        ListenerFlowController.ListenerFlowLatestResponse response = new ListenerFlowController.ListenerFlowLatestResponse();

        Test.startTest();
        ListenerFlowController.preparingResponse(response, historyRecordsMap, listenerConfigRec, new Map<Id, Map<String, Id>>(), sObjectMap, sortingDateTimeMap);
        Test.stopTest();
    }

    @IsTest
    static void testPreparingResponse_Scenario2() {
        // Create test data
        ListenerFlowController.ListenerFlowLatestResponse result = new ListenerFlowController.ListenerFlowLatestResponse();
        Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
        Flowdometer__Listener__c listenerConfigRec = new Flowdometer__Listener__c();
        listenerConfigRec.Flowdometer__Object_Name__c = 'Case';
        listenerConfigRec.Flowdometer__Field_To_Track__c = 'Status';
        listenerConfigRec.Flowdometer__TerminalStage__c = 'isClosed';
        insert listenerConfigRec;
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



        // Call the method to be tested
        Test.startTest();
        ListenerFlowController.preparingResponse(result, historyRecordsMap, listenerConfigRec, goalStepRecsMap, sObjectMap, sortingDateTimeMap);
        Test.stopTest();

        // Assertions
        System.assertEquals(true, result.hasRecords);
    }

    @isTest
    static void testPreparingResponse() {
        // Create test data

        // Create a ListenerFlowLatestResponse object for testing
        ListenerFlowController.ListenerFlowLatestResponse result = new ListenerFlowController.ListenerFlowLatestResponse();

        // Create a Flowdometer__Listener__c object for listenerConfigRec
        Flowdometer__Listener__c listenerConfigRec = new Flowdometer__Listener__c(
            Flowdometer__Object_Name__c = 'Opportunity',
            Flowdometer__Field_To_Track__c = 'stageName',
            Flowdometer__TerminalStage__c = 'IsWon'
        );
        insert listenerConfigRec;

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

        // ------------------------------
        // Miscellaneous Test Methods
        // ------------------------------

        // Create a Map<Id, Map<String, Id>> for goalStepRecsMap
        Map<Id, Map<String, Id>> goalStepRecsMap = new Map<Id, Map<String, Id>>();
        // Add any required data for goalStepRecsMap

        // Create a Map<String, SObject> for sObjectMap
        Map<Id, SObject> sObjectMap = new Map<Id, SObject>();

        // Add any required data for sObjectMap

        // Call the preparingResponse method
        Test.startTest();
        ListenerFlowController.preparingResponse(result, historyRecordsMap, listenerConfigRec, goalStepRecsMap, sObjectMap);
        Test.stopTest();

        // Assert the expected results
        System.assertEquals(true, result.hasRecords);
    }
}
