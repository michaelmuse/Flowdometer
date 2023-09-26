/*
  Class: ListenerFlowControllerTest
  Path: force-app\main\default\classes\ListenerFlowControllerTest.cls
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
        
        // -------------- Opportunity Setup --------------
        // Standard Opportunity
        Opportunity opportunity = TestDataFactory.createOpportunity('Test Opportunity', 'Prospecting', Date.today().addDays(10));
    
        // Opportunity for preparingResponse tests
        Opportunity opportunityForUpdate = TestDataFactory.createOpportunity('Test Opportunity For Update', 'Prospecting', Date.today().addDays(10));
        
        opportunityForUpdate.stageName = 'Qualification';
        update opportunityForUpdate;
        // set parentId to opportunity.accountId
        Id parentId = opportunity.accountId;
        // Opportunity History Records
        List<Opportunity> oppHistoryRecords = TestDataFactory.createOpportunityHistoryRecords(2, 'stageName');
        Account testAccount = TestDataFactory.createAccount('Test Account');
        List<Opportunity> opps = TestDataFactory.createAndUpdateOpportunities(testAccount.Id, 'stageName', 2);

        // Opportunity History Records for preparingResponse tests
        List<SObject> oppHistoryRecordsSObject = new List<SObject>();
        for(Opportunity opp : oppHistoryRecords) {
            oppHistoryRecordsSObject.add((SObject)opp);
        }
        // historyRecordsMap = new Map<Id, List<SObject>>();
        // // historyRecordsMap.put(opportunity.Id, oppHistoryRecordsSObject);
        // initializeHistoryRecordsMap(opportunity);
        // Initialize historyRecordsMap here
        List<Opportunity> oppList = [SELECT Id FROM Opportunity];
        initializeHistoryRecordsMap(oppList);
        System.debug('After putting in map: historyRecordsMap = ' + historyRecordsMap);

        // -------------- Case Setup --------------
        // Standard Case Record
        parentCase = TestDataFactory.createCase('Test Case', 'New');
    
        // Case History Records
        List<CaseHistory> caseHistoryRecords = TestDataFactory.createCaseHistoryRecords(parentCase.Id, 'Status', 2);
        insert caseHistoryRecords;

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
    
        // Store the listener records for use in test methods
        testListeners = [SELECT Id, Object_Name__c FROM Listener__c];
    }
    public class OpportunityFieldHistoryWrapper {
      public Id OpportunityId;
      public String OldValue;
      public String NewValue;
      public String FieldName;
      
      public OpportunityFieldHistoryWrapper(Id oppId, String oldValue, String newValue, String fieldName) {
          this.OpportunityId = oppId;
          this.OldValue = oldValue;
          this.NewValue = newValue;
          this.FieldName = fieldName;
      }

      // Convert the wrapper to a map that resembles an SObject
      public Map<String, Object> toSObjectMap() {
        return new Map<String, Object>{
            'OpportunityId' => this.OpportunityId,
            'OldValue' => this.OldValue,
            'NewValue' => this.NewValue,
            'FieldName' => this.FieldName
        };
      }
    }
  
    public static void initializeHistoryRecordsMap(List<Opportunity> opportunities) {
        System.debug('initializeHistoryRecordsMap called');
        List<Id> oppIds = new List<Id>();
        for (Opportunity opportunity : opportunities) {
            oppIds.add(opportunity.Id);
        }

        // Query OpportunityHistory based on Opportunity Ids
        List<OpportunityFieldHistory> oppHistories = [SELECT Id, OpportunityId 
                                                 FROM OpportunityFieldHistory 
                                                 WHERE OpportunityId IN :oppIds];
        System.debug('Number of Opportunity History records: ' + oppHistories.size());
        System.debug('Opportunity History records: ' + oppHistories);

        // Initialize if null
        if (historyRecordsMap == null) {
            historyRecordsMap = new Map<Id, List<SObject>>();
        }

        // Populate historyRecordsMap
        for (OpportunityFieldHistory oppHistory : oppHistories) {
            if (!historyRecordsMap.containsKey(oppHistory.OpportunityId)) {
                historyRecordsMap.put(oppHistory.OpportunityId, new List<SObject>());
            }
            historyRecordsMap.get(oppHistory.OpportunityId).add((SObject)oppHistory);
        }
        System.debug('historyRecordsMap' + historyRecordsMap);
    }
    // public static void initializeHistoryRecordsMap(Opportunity opportunity) {
    //     System.debug('initializeHistoryRecordsMap called');
    //     Opportunity opp = [SELECT Id, Name, StageName, CloseDate FROM Opportunity WHERE Id = :opportunity.Id];
    //     System.debug('Fetched opportunity: ' + opp);
    //     // Initialize if null
    //     if(historyRecordsMap == null) {
    //         historyRecordsMap = new Map<Id, List<SObject>>();
    //     }
    //     // Use the Opportunity Id from historyRecordsMap to query OpportunityHistory
    //     List<Id> oppHistoryRecordIds = new List<Id>(historyRecordsMap.keySet());

    //     List<OpportunityHistory> oppHistories = [SELECT Id, StageName 
    //                                             FROM OpportunityHistory 
    //                                             WHERE OpportunityId IN :oppHistoryRecordIds];
    //     System.debug('opp' + opp);
    //     System.debug('oppHistories' + oppHistories);
    
    //     // Cast list of OpportunityHistory to list of SObject
    //     List<SObject> oppHistoriesAsSObjects = new List<SObject>();
    //     for(OpportunityHistory oppHistory : oppHistories) {
    //         oppHistoriesAsSObjects.add((SObject)oppHistory);
    //     }
    //     System.debug('oppHistoriesAsSObjects' + oppHistoriesAsSObjects);
    
    //     // Now, populate the historyRecordsMap
    //     // historyRecordsMap = new Map<Id, List<SObject>>();
    //     historyRecordsMap.put(opp.Id, oppHistoriesAsSObjects);
    //     System.debug('historyRecordsMap' + historyRecordsMap);
    // }
    // Executes the main test logic and returns the response list
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

    @isTest
    static void testPreparingResponse_Scenario1() {
        // Fetch listenerConfigWExecution from @TestSetup
        String stageName = 'stageName';  

        Listener__c listenerConfigWExecution = [
            SELECT Id, Last_Execution_On__c, Object_Name__c, Field_To_Track__c, TerminalStage__c 
            FROM Listener__c 
            WHERE Last_Execution_On__c != null AND Field_To_Track__c = :stageName
            LIMIT 1
        ];
        System.debug('listenerConfigWExecution: ' + listenerConfigWExecution);
        DateTime lastExecutionOn = listenerConfigWExecution.Last_Execution_On__c;

        // Query for an Opportunity record
        Opportunity opportunity = [SELECT Id, Name, StageName, CloseDate FROM Opportunity LIMIT 1];
        System.debug('Queried opportunity: ' + opportunity);

        // Query for Opportunity History records related to the Opportunity
        // List<OpportunityFieldHistory> oppFieldHistories = [
        //     SELECT Id, OpportunityId, NewValue, OldValue, Field, CreatedDate
        //     FROM OpportunityFieldHistory
        //     WHERE OpportunityId = :opportunity.Id
        //     ORDER BY CreatedDate DESC
        // ];

        System.debug('oppFieldHistories size: ' + oppFieldHistories.size());
        System.debug('oppFieldHistories: ' + oppFieldHistories);
        System.assert(oppFieldHistories.size() > 0, 'oppFieldHistories should have elements');

        // Initialize historyRecordsMap and populate it
        Map<Id, List<SObject>> historyRecordsMap = new Map<Id, List<SObject>>();
        List<SObject> oppFieldHistoriesSObject = new List<SObject>();
        for (OpportunityFieldHistory oppFieldHistory : oppFieldHistories) {
            oppFieldHistoriesSObject.add((SObject)oppFieldHistory);
        }
        historyRecordsMap.put(opportunity.Id, oppFieldHistoriesSObject);

        // Debug to ensure it's populated
        System.debug('historyRecordsMap: ' + historyRecordsMap);

        // Get the queryModifiers
        Map<String, Object> queryModifiers = ListenerFlowController.getQueryModifiers(true, lastExecutionOn);
        // Listener__c listenerConfig = [SELECT Id, Last_Execution_On__c, Object_Name__c, Field_To_Track__c, TerminalStage__c FROM Listener__c LIMIT 1];
        // Test.setCreatedDate(listenerConfig.id, oneHourBefore);


        Map<Id, List<Datetime>> sortingDateTimeMap = new Map<Id, List<Datetime>>();
        // Populate sortingDateTimeMap for this specific test
        sortingDateTimeMap.put(opportunity.Id, new List<Datetime>{DateTime.now()});

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
        System.assert(historyRecordsMap.size() > 0, 'historyRecordsMap should have elements');
        System.assert(historyRecordsMap.values().size() > 0, 'historyRecordsMap values should have elements');

        // Call runTest specifically to test preparingResponse
        List<ListenerFlowController.ListenerFlowLatestResponse> records = runTest(
            listenerConfigWExecution, 
            historyRecordsMap, 
            response, 
            additionalParams, 
            sObjectMap, 
            sortingDateTimeMap
        );
        System.debug('State of response after runTest: ' + response);

        // Assertions
        // Validate that response is populated as expected
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assert(response.lstListenerFlow != null, 'lstListenerFlow should not be null');
        System.assert(response.lstListenerFlow.size() > 0, 'lstListenerFlow should have elements');
        System.assert(response.hasRecords, 'hasRecords should be true');
    }
}