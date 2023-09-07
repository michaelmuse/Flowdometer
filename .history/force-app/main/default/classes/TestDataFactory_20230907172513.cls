//force-app\main\default\classes\TestDataFactory.cls

/*
    TestDataFactory Class Method Summary:

    1. createOpportunityHistoryRecords
       - Parameters: 
         - Id parentId: The parent Opportunity Id
         - String field: The field name for history tracking
         - Integer numRecords: The number of history records to create
       - Returns: List<OpportunityFieldHistory>

    2. createCaseHistoryRecords
       - Parameters:
         - Id parentId: The parent Case Id
         - String field: The field name for history tracking
         - Integer numRecords: The number of history records to create
       - Returns: List<CaseHistory>

    3. createListenerConfig
       - Parameters:
         - DateTime lastExecutionOn: The last execution time for the Listener
       - Returns: Flowdometer__Listener__c

    4. createOpportunity
       - Parameters:
         - String stageName: The stage name for the Opportunity
       - Returns: Opportunity

    5. createHistoryRecords
       - Parameters:
         - Integer numRecords: The number of History__c records to create
       - Returns: List<History__c>

    6. createCustomObjects
       - Parameters:
         - Integer numRecords: The number of CustomObject__c records to create
       - Returns: List<CustomObject__c>
*/

public class TestDataFactory {
  public static List<OpportunityFieldHistory> createOpportunityHistoryRecords(
    Id parentId,
    String field,
    Integer numRecords
  ) {
    List<OpportunityFieldHistory> records = new List<OpportunityFieldHistory>();
    for (Integer i = 0; i < numRecords; i++) {
      OpportunityFieldHistory historyRecord = new OpportunityFieldHistory();
      historyRecord.OpportunityId = parentId;
      historyRecord.Field = field;
      records.add(historyRecord);
    }
    return records;
  }

  public static List<CaseHistory> createCaseHistoryRecords(
    Id parentId,
    String field,
    Integer numRecords
  ) {
    List<CaseHistory> records = new List<CaseHistory>();
    for (Integer i = 0; i < numRecords; i++) {
      CaseHistory historyRecord = new CaseHistory();
      historyRecord.CaseId = parentId;
      historyRecord.Field = field;
      records.add(historyRecord);
    }
    return records;
  }

  public static Flowdometer__Listener__c createListenerConfig(
    DateTime lastExecutionOn,
    Boolean insertRecord
  ) {
    Flowdometer__Listener__c listenerConfig = new Flowdometer__Listener__c(
      Flowdometer__Object_Name__c = 'Opportunity',
      Flowdometer__Field_To_Track__c = 'StageName',
      Flowdometer__Terminal_Stage__c = 'IsWon',
      Flowdometer__Last_Execution_On__c = lastExecutionOn
    );

    if (insertRecord) {
      insert listenerConfig;
    }

    return listenerConfig;
  }

  public static Opportunity createOpportunity(String stageName) {
    Opportunity opp = new Opportunity(
      Name = 'Test Opportunity',
      StageName = stageName,
      CloseDate = Date.today().addDays(10)
    );
    insert opp; // Insert the Opportunity record
    return opp;
  }

  public static List<History__c> createHistoryRecords(Integer numRecords) {
    List<History__c> historyRecords = new List<History__c>();
    for (Integer i = 0; i < numRecords; i++) {
      historyRecords.add(
        new History__c()
          // Populate required fields here
      );
    }
    insert historyRecords; // Insert the History__c records
    return historyRecords;
  }

  public static List<CustomObject__c> createCustomObjects(Integer numRecords) {
    List<CustomObject__c> customObjects = new List<CustomObject__c>();
    for (Integer i = 0; i < numRecords; i++) {
      customObjects.add(
        new CustomObject__c()
          // Populate required fields here
      );
    }
    insert customObjects; // Insert the CustomObject__c records
    return customObjects;
  }
}