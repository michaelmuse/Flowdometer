@isTest
private class ListenerFlowControllerTest {
  @isTest
  static void testParseRecordsToFlow() {
    // Create test data
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

    ListenerFlowController.ListenerFlowLatestRequest request = new ListenerFlowController.ListenerFlowLatestRequest();
    request.listenerConfig = listenerConfig;

    Test.startTest();
    List<ListenerFlowController.ListenerFlowLatestResponse> responseList = ListenerFlowController.parseRecordsToFlow(
      new List<ListenerFlowController.ListenerFlowLatestRequest>{ request }
    );
    Test.stopTest();
  }

  @isTest
  static void testGetWhereClause() {
    Flowdometer__Listener__c listenerConfig = new Flowdometer__Listener__c(
      Flowdometer__Last_Execution_On__c = DateTime.newInstanceGmt(
        2023,
        6,
        1,
        0,
        0,
        0
      )
    );
    String whereClause = ListenerFlowController.getWhereClause(
      listenerConfig,
      true
    );

    // Convert the expected and actual values to GMT-based String objects
    String expectedDateTime = (DateTime.newInstanceGmt(2023, 6, 1, 0, 0, 0))
      .formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    String actualDateTime = whereClause.substringAfter('>= ');

    System.assertEquals(expectedDateTime, actualDateTime);
  }

  @isTest
  static void testCollectAllHistoryRecordsOnFirstRun() {
    // Create test data
    Flowdometer__Listener__c listenerConfig = new Flowdometer__Listener__c(
      Flowdometer__Object_Name__c = 'Opportunity',
      Flowdometer__Field_To_Track__c = 'StageName',
      Flowdometer__TerminalStage__c = 'IsWon',
      Flowdometer__Last_Execution_On__c = null // Ensure this is null to trigger collectAllHistoryRecordsOnFirstRun
    );
    insert listenerConfig;

    Opportunity opportunity = new Opportunity(
      Name = 'Test Opportunity',
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(10)
    );
    insert opportunity;

    // Generate initial history records
    opportunity.StageName = 'Qualification';
    update opportunity;

    // Create a request object
    ListenerFlowController.ListenerFlowLatestRequest request = new ListenerFlowController.ListenerFlowLatestRequest();
    request.listenerConfig = listenerConfig;

    // Call the method to be tested
    Test.startTest();
    List<ListenerFlowController.ListenerFlowLatestResponse> responseList = ListenerFlowController.parseRecordsToFlow(
      new List<ListenerFlowController.ListenerFlowLatestRequest>{ request }
    );
    Test.stopTest();

    // Assert: Check if all history records are returned
    // Note: You'll need to adjust this based on what collectAllHistoryRecordsOnFirstRun actually does
    System.assertEquals(
      2,
      responseList[0].historyRecords.size(),
      'Unexpected number of history records returned'
    );
  }

  @isTest
  static void testGetStringNotNull() {
    String value = ListenerFlowController.getStringNotNull('Hello');
    System.assertEquals('Hello', value);

    value = ListenerFlowController.getStringNotNull(null);
    System.assertEquals('', value);
  }

  @isTest
  static void testIsCustomObject() {
    Boolean isCustom = ListenerFlowController.isCustomObject('Account');
    System.assertEquals(false, isCustom);
  }

  @isTest
  static void testGetLatestHistoryValues() {
    // Create test data
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

    Set<String> targetRecords = new Set<String>{ opportunity.Id };

    Test.startTest();
    Map<Id, List<SObject>> historyRecordsMap = ListenerFlowController.getLatestHistoryValues(
      targetRecords,
      listenerConfig
    );
    Test.stopTest();
  }

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

    Set<String> targetRecords = new Set<String>{ opportunity.Id };

    Map<Id, List<SObject>> historyRecordsMap = ListenerFlowController.getLatestHistoryValues(
      targetRecords,
      listenerConfig
    );

    ListenerFlowController.ListenerFlowLatestResponse response = new ListenerFlowController.ListenerFlowLatestResponse();

    Test.startTest();
    ListenerFlowController.preparingResponse(
      response,
      historyRecordsMap,
      listenerConfig,
      new Map<Id, Map<String, Id>>(),
      sObjectMap
    );
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
    Map<String, SObject> sObjectMap = new Map<String, SObject>();

    // Create a case record and related history records
    Case parentCase = new Case(Subject = 'Test Case', Status = 'New');
    insert parentCase;

    List<CaseHistory> historyRecords = new List<CaseHistory>();
    historyRecords.add(createCaseHistoryRecord(parentCase.Id, 'created'));
    historyRecordsMap.put(parentCase.Id, historyRecords);

    // Call the method to be tested
    Test.startTest();
    ListenerFlowController.preparingResponse(
      result,
      historyRecordsMap,
      listenerConfig,
      goalStepRecsMap,
      sObjectMap
    );
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

    List<OpportunityFieldHistory> historyRecords = new List<OpportunityFieldHistory>();
    historyRecords.add(
      createOpportunityHistoryRecord(opportunity.Id, 'created')
    );
    historyRecords.add(
      createOpportunityHistoryRecord(opportunity.Id, 'updated')
    );
    historyRecordsMap.put(opportunity.Id, historyRecords);

    // Create a Map<Id, Map<String, Id>> for goalStepRecsMap
    Map<Id, Map<String, Id>> goalStepRecsMap = new Map<Id, Map<String, Id>>();
    // Add any required data for goalStepRecsMap

    // Create a Map<String, SObject> for sObjectMap
    Map<String, SObject> sObjectMap = new Map<String, SObject>();
    // Add any required data for sObjectMap

    // Call the preparingResponse method
    Test.startTest();
    ListenerFlowController.preparingResponse(
      result,
      historyRecordsMap,
      listenerConfig,
      goalStepRecsMap,
      sObjectMap
    );
    Test.stopTest();

    // Assert the expected results
    System.assertEquals(true, result.hasRecords);
  }

  // Helper method to create a history record
  static OpportunityFieldHistory createOpportunityHistoryRecord(
    Id parentId,
    String field
  ) {
    OpportunityFieldHistory historyRecord = new OpportunityFieldHistory();
    historyRecord.put('OpportunityId', parentId);
    historyRecord.put('Field', field);

    return historyRecord;
  }
  static CaseHistory createCaseHistoryRecord(Id parentId, String field) {
    CaseHistory historyRecord = new CaseHistory();
    historyRecord.put('CaseId', parentId);
    historyRecord.put('Field', field);

    return historyRecord;
  }
}
