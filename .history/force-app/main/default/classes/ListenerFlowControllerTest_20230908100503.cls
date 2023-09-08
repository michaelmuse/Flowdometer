//force-app\main\default\classes\ListenerFlowControllerTest.cls
@isTest
private class ListenerFlowControllerTest {
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
    @isTest
    static void setupTestData() {
        // Initialize your TestDataFactory
        TestDataFactory testDataFactory = new TestDataFactory();
        
        // Initialize your historyRecordsMap
        Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
        
        // Create and insert an Opportunity record
        Opportunity opportunity = new Opportunity(Name = 'Test Opp', StageName = 'Prospecting', CloseDate = Date.today());
        insert opportunity;
        
        // Use TestDataFactory to create history records for Opportunity
        List<OpportunityFieldHistory> oppHistoryRecords = testDataFactory.createOpportunityHistoryRecords(opportunity.Id, 'StageName', 2);
        historyRecordsMap.put(opportunity.Id, new List<SObject>(oppHistoryRecords));
        
        // Create and insert a Case record
        Case parentCase = new Case(Subject = 'Test Case', Status = 'New');
        insert parentCase;
        
        // Use TestDataFactory to create history records for Case
        List<CaseHistory> caseHistoryRecords = testDataFactory.createCaseHistoryRecords(parentCase.Id, 'Status', 2);
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

    // Creates a Listener Config record for testing
    static Flowdometer__Listener__c createListenerConfig(DateTime lastExecutionOn) {
        Flowdometer__Listener__c listenerConfig = TestDataFactory.createListenerConfig(lastExecutionOn);
        insert listenerConfig;
        return listenerConfig;
    }

    // Creates an Opportunity record for testing
    static Opportunity createAndUpdateOpportunity(String newStage) {
        Opportunity opportunity = TestDataFactory.createOpportunity('Prospecting');
        insert opportunity;
        opportunity.StageName = newStage;
        update opportunity;
        return opportunity;
    }

    // Executes the main test logic and returns the response list
    static List<ListenerFlowController.ListenerFlowLatestResponse> runTest(Flowdometer__Listener__c listenerConfig, Map<Id, List<SObject>> historyRecordsMap) {
        ListenerFlowController.ListenerFlowLatestRequest request = new ListenerFlowController.ListenerFlowLatestRequest();
        request.listenerConfig = listenerConfig;

        // Get query modifiers based on the listenerConfig
        Map<String, Object> queryModifiers = ListenerFlowController.getQueryModifiers(listenerConfig);

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

        setupTestData();

        // Create test data without inserting the record
        Flowdometer__Listener__c listenerConfig = TestDataFactory.createListenerConfig(null, false); // Passing null for lastExecutionOn and false for insertRecord

        // Now insert the record
        insert listenerConfig;

        Opportunity opportunity = TestDataFactory.createOpportunity('Prospecting');
        insert opportunity;

        ListenerFlowController.ListenerFlowLatestRequest request = new ListenerFlowController.ListenerFlowLatestRequest();
        request.listenerConfig = listenerConfig;

        // Get query modifiers based on the listenerConfig
        Map<String, Object> queryModifiers = ListenerFlowController.getQueryModifiers(listenerConfig);

        Test.startTest();
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = ListenerFlowController.parseRecordsToFlow(new List<ListenerFlowController.ListenerFlowLatestRequest>{request}, queryModifiers);
        Test.stopTest();
    }

    // Test the logic for fetching the latest history values
    @isTest
    static void testGetLatestHistoryValues() {
        // Create test data
        setupTestData();

        // Use TestDataFactory to create ListenerConfig and Opportunity records
        Flowdometer__Listener__c listenerConfig = TestDataFactory.createListenerConfig(DateTime.now());
        insert listenerConfig;

        Opportunity opportunity = TestDataFactory.createOpportunity('Prospecting');
        insert opportunity;

        opportunity.StageName = 'Qualification';
        update opportunity;

        Set<String> targetRecords = new Set<String>{opportunity.Id};

        Test.startTest();
        Map<Id, List<SObject>> historyRecordsMap = ListenerFlowController.getLatestHistoryValues(targetRecords, listenerConfig);
        Test.stopTest();
    }

    // Test the that our query will max out at 10k records
    @isTest
    static void testQueryResponseLimit() {
        // Create test data
        Flowdometer__Listener__c listenerConfig = createListenerConfig(DateTime.now());
        insert listenerConfig;

        Opportunity opportunity = createAndUpdateOpportunity('Proposal');
        insert opportunity;

        // Create a Map to hold the history records
        Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
        historyRecordsMap.put(opportunity.Id, new List<SObject>(historyRecords));

        // Create more than 10,000 history records
        List<OpportunityFieldHistory> historyRecords = new List<OpportunityFieldHistory>();
        for(Integer i = 0; i < 10001; i++) {
            historyRecords.add(createOpportunityHistoryRecord(opportunity.Id, 'updated'));
        }
        // Note: I don't think I can mock these records, since I'm testing the query itself. Maybe I need to test the result of parseHistory (if DML limits are reached)?
            // Maybe I need to pass an optional parameter to parseRecordsToFlow that allows me to pass in the mocked history records? Here's the method:
                                // @InvocableMethod(label='Query & Parse History Records', description='Collect history tracking records after you have turned on history tracking', category='ListenerFlowController')
                                // public static List<ListenerFlowLatestResponse> parseRecordsToFlow(List<ListenerFlowLatestRequest> listenerConfigList, Listener__c listenerConfig)

        // Run the test
        Test.startTest();
        // Pass the populated historyRecordsMap
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = runTest(listenerConfig, historyRecordsMap);
        Test.stopTest();

        // Assert: Check if only 10,000 records are returned
        assertHistoryRecords(responseList, 10000);
    }

    @isTest
    static void testQueryResponseSortedByCreatedDateAndMillis() {
        // Create test data
        Flowdometer__Listener__c listenerConfig = createListenerConfig(DateTime.now());
        insert listenerConfig;

        Opportunity opportunity = createAndUpdateOpportunity('Proposal');
        insert opportunity;

        // Mock history records with the same CreatedDate but different milliseconds
        List<OpportunityFieldHistory> historyRecords = new List<OpportunityFieldHistory>();
        for(Integer i = 0; i < 5; i++) {
            OpportunityFieldHistory record = createOpportunityHistoryRecord(opportunity.Id, 'updated');
            // Mock milliseconds by adding a custom field to your OpportunityFieldHistory object
            // record.Custom_Milliseconds__c = i;
            historyRecords.add(record);
        }

        // Create a Map to hold the history records
        Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
        historyRecordsMap.put(opportunity.Id, new List<SObject>(historyRecords));

        // Run the test
        Test.startTest();
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = runTest(listenerConfig, historyRecordsMap);
        Test.stopTest();

        // Assert: Check if the records are sorted by CreatedDate and milliseconds
        // You'll need to add logic to compare the milliseconds
        // This is just a placeholder for your actual assertion logic
        // System.assertEquals(expectedOrder, actualOrder);

        // Assuming you have a way to get the milliseconds from your history records
        // and that they are stored in a List<SObject> in your response
        List<SObject> sortedHistoryRecords = responseList[0].historyRecords;
        for(Integer i = 1; i < sortedHistoryRecords.size(); i++) {
            Datetime prevDate = (Datetime)sortedHistoryRecords[i-1].get('CreatedDate');
            Datetime currDate = (Datetime)sortedHistoryRecords[i].get('CreatedDate');
            // Add your logic to get milliseconds if needed
            // Integer prevMillis = (Integer)sortedHistoryRecords[i-1].get('Custom_Milliseconds__c');
            // Integer currMillis = (Integer)sortedHistoryRecords[i].get('Custom_Milliseconds__c');

            // Your assertion logic here
            System.assert(currDate >= prevDate, 'Records are not sorted by CreatedDate');
            // System.assert(currMillis >= prevMillis, 'Records with the same CreatedDate are not sorted by milliseconds');
        }
    }

    // Test the logic for collecting history records since the last query
    @isTest
    static void testCollectHistoryRecordsSinceLastQuery() {
        Flowdometer__Listener__c listenerConfig = TestDataFactory.createListenerConfig(DateTime.now());
        listenerConfig.Flowdometer__Last_Execution_On__c = DateTime.now().addMinutes(-10);
        
        Opportunity opportunity = TestDataFactory.createOpportunity('Proposal');
        insert opportunity;

        // Create an empty Map to simulate no history records
        Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();

        // Run the test
        Test.startTest();
        // Pass the empty historyRecordsMap
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = runTest(listenerConfig, historyRecordsMap);
        Test.stopTest();

        // Assert: Check if only the new history records are returned
        assertHistoryRecords(responseList, 1, 'Proposal');
    }    

    // Test the logic for collecting all history records on the first run
    @isTest
    static void testCollectAllHistoryRecordsOnFirstRun() {
        Flowdometer__Listener__c listenerConfig = createListenerConfig(null);  // Passing null to simulate first run
        Opportunity opportunity = createAndUpdateOpportunity('Qualification');

        // Create a history record for the Opportunity
        // Note: You might need to mock this record or use some other method to create it
        OpportunityFieldHistory historyRecord = TestDataFactory.createSingleOpportunityHistoryRecord(opportunity.Id, 'updated');
        insert historyRecord;

        // Create a Map to hold the history records
        Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
        historyRecordsMap.put(opportunity.Id, new List<SObject>{historyRecord});

        // Run the test
        Test.startTest();
        // Pass the populated historyRecordsMap
        List<ListenerFlowController.ListenerFlowLatestResponse> responseList = runTest(listenerConfig, historyRecordsMap);
        Test.stopTest();

        // Assert: Check if all history records are returned
        assertHistoryRecords(responseList, 1);  // Expecting 1 history record

        // Additional Assert: Check if the history record is the one we created
        ListenerFlowController.ListenerFlowLatestResponse response = responseList[0];
        System.assertEquals(historyRecord.Id, response.lstListenerFlow[0].varHistoryRecordId, 'History record ID should match');
    }

    static void assertHistoryRecords(List<ListenerFlowController.ListenerFlowLatestResponse> responseList, Integer expectedCount) {
        assertHistoryRecords(responseList, expectedCount, null);
    }

    @isTest
    static void testBulkOperations() {
        // Arrange
        // Use TestDataFactory to create History__c records
        List<History__c> historyRecords = TestDataFactory.createHistoryRecords(200);
        insert historyRecords;

        // Create a Listener__c record for testing
        Listener__c listenerConfig = new Listener__c(
            Object_Name__c = 'History__c',  // Replace with the actual object name
            Field_To_Track__c = 'Field1__c'  // Replace with the actual field name
        );
        insert listenerConfig;

        // Act
        Test.startTest();
        // Call getLatestHistoryValues method
        Map<String, Object> queryModifiers = ListenerFlowController.getQueryModifiers(listenerConfig);
        Set<Id> parentIds = new Set<Id>(); // Populate this with the parent Ids related to your History__c records
        for(History__c record : historyRecords) {
            parentIds.add(record.ParentId__c);  // Replace with the actual parent Id field
        }
        Map<Id, List<SObject>> result = ListenerFlowController.getLatestHistoryValues(parentIds, listenerConfig, queryModifiers);
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
        Flowdometer__Listener__c listenerConfig = TestDataFactory.createListenerConfig(DateTime.now(), true);
        // No need to insert here, as it's done in the factory method
    
        // Act
        Test.startTest();
        // Call parseRecordsToFlow method
        ListenerFlowController.ListenerFlowLatestRequest request = new ListenerFlowController.ListenerFlowLatestRequest();
        request.listenerConfig = listenerConfig;
        List<ListenerFlowController.ListenerFlowLatestResponse> responses = ListenerFlowController.parseRecordsToFlow(new List<ListenerFlowController.ListenerFlowLatestRequest>{request}, listenerConfig);
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
        Flowdometer__Listener__c listenerConfig = new Flowdometer__Listener__c(
            Flowdometer__Object_Name__c = 'Opportunity',
            Flowdometer__Field_To_Track__c = 'StageName',
            Flowdometer__TerminalStage__c = 'IsWon',
            Flowdometer__Last_Execution_On__c = oneHourBefore
        );
        insert listenerConfig;
        Test.setCreatedDate(listenerConfig.id, oneHourBefore);

        Opportunity opportunity = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10)
        );
        insert opportunity;

        opportunity.StageName = 'Qualification';
        update opportunity;

        Map<String, SObject> sObjectMap = new Map<String, SObject>{
            opportunity.Id => opportunity
        };

        Set<Id> targetRecords = new Set<Id>{opportunity.Id};

        Map<Id, List<SObject>> historyRecordsMap = ListenerFlowController.getLatestHistoryValues(targetRecords, listenerConfig);

        ListenerFlowController.ListenerFlowLatestResponse response = new ListenerFlowController.ListenerFlowLatestResponse();

        Test.startTest();
        ListenerFlowController.preparingResponse(response, historyRecordsMap, listenerConfig, new Map<Id, Map<String, Id>>(), sObjectMap);
        Test.stopTest();
    }

    @IsTest
    static void testPreparingResponse_Scenario2() {
        // Create test data
        ListenerFlowController.ListenerFlowLatestResponse result = new ListenerFlowController.ListenerFlowLatestResponse();
        Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
        Flowdometer__Listener__c listenerConfig = new Flowdometer__Listener__c();
        listenerConfig.Flowdometer__Object_Name__c = 'Case';
        listenerConfig.Flowdometer__Field_To_Track__c = 'Status';
        listenerConfig.Flowdometer__TerminalStage__c = 'isClosed';
        insert listenerConfig;
        Map<Id, Map<String, Id>> goalStepRecsMap = new Map<Id, Map<String, Id>>();
        Map<Id, SObject> sObjectMap = new Map<Id, SObject>();

        // Create a case record and related history records
        Case parentCase = new Case(
            Subject = 'Test Case',
            Status = 'New'
        );
        insert parentCase;



        // Call the method to be tested
        Test.startTest();
        ListenerFlowController.preparingResponse(result, historyRecordsMap, listenerConfig, goalStepRecsMap, sObjectMap);
        Test.stopTest();

        // Assertions
        System.assertEquals(true, result.hasRecords);
    }

    @isTest
    static void testPreparingResponse() {
        // Create test data

        // Create a ListenerFlowLatestResponse object for testing
        ListenerFlowController.ListenerFlowLatestResponse result = new ListenerFlowController.ListenerFlowLatestResponse();

        // Create a Flowdometer__Listener__c object for listenerConfig
        Flowdometer__Listener__c listenerConfig = new Flowdometer__Listener__c(
            Flowdometer__Object_Name__c = 'Opportunity',
            Flowdometer__Field_To_Track__c = 'StageName',
            Flowdometer__TerminalStage__c = 'IsWon'
        );
        insert listenerConfig;

        Opportunity opportunity = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10)
        );
        insert opportunity;

        opportunity.StageName = 'Qualification';
        update opportunity;

        // Create a Map<Id, List<sObject>> for historyRecordsMap
        Map<Id, List<sObject>> historyRecordsMap = new Map<Id, List<sObject>>();

        // ------------------------------
        // Miscellaneous Test Methods
        // ------------------------------

        // Create a Map<Id, Map<String, Id>> for goalStepRecsMap
        Map<Id, Map<String, Id>> goalStepRecsMap = new Map<Id, Map<String, Id>>();
        // Add any required data for goalStepRecsMap

        // Create a Map<String, SObject> for sObjectMap
        Map<String, SObject> sObjectMap = new Map<String, SObject>();
        // Add any required data for sObjectMap

        // Call the preparingResponse method
        Test.startTest();
        ListenerFlowController.preparingResponse(result, historyRecordsMap, listenerConfig, goalStepRecsMap, sObjectMap);
        Test.stopTest();

        // Assert the expected results
        System.assertEquals(true, result.hasRecords);
    }
}
