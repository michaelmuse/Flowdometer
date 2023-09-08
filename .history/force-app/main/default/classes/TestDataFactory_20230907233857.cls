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

  public static List<Opportunity> createAndUpdateOpportunities(
    Id parentId,
    String field,
    Integer numRecords
  ) {
    // Create Opportunities
    List<Opportunity> opps = new List<Opportunity>();
    for (Integer i = 0; i < numRecords; i++) {
      Opportunity opp = new Opportunity(
        Name='Test Opp ' + i,
        StageName='Prospecting',
        CloseDate=System.today(),
        AccountId=parentId  // Assuming parentId is an Account Id
      );
      opps.add(opp);
    }
    insert opps;

    // Update Opportunities to generate history records
    for (Opportunity opp : opps) {
      opp.put(field, 'New Value ' + DateTime.now().getTime());  // Update the field to track
    }
    update opps;

    return opps;  // Return the list of updated Opportunities
  }

  public static List<CaseHistory> createCaseHistoryRecords(
    Id parentId,
    String field,
    Integer numRecords
  ) {
    // Similar logic can go here for CaseHistory
    // ...
    return new List<CaseHistory>();
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
}

  // public static List<History__c> createHistoryRecords(Integer numRecords) {
  //   //List<History__c> historyRecords = new List<History__c>();
  //   List<YourCustomObject__c> historyRecords = new List<YourCustomObject__c>();
  //   for (Integer i = 0; i < numRecords; i++) {
  //     // historyRecords.add(
  //     //   new History__c()
  //     //     // Populate required fields here
  //     // );
  //     List<YourCustomObject__c> historyRecords = new List<YourCustomObject__c>();
  //     historyRecords.add(
  //         new YourCustomObject__c()
  //           // Populate required fields here
  //     );
  //   }
  //   insert historyRecords; // Insert the History__c records
  //   return historyRecords;
  // }
  //   public static List<YourCustomObject__c> createHistoryRecords(Integer numRecords) {
  //     List<YourCustomObject__c> historyRecords = new List<YourCustomObject__c>();
  //     for (Integer i = 0; i < numRecords; i++) {
  //         historyRecords.add(
  //             new YourCustomObject__c()
  //                 // Populate required fields here
  //         );
  //     }
  //     insert historyRecords; // Insert the custom object records
  //     return historyRecords;
  // }
  // Replace YourCustomObject__c with the actual API name of the custom object
  public static List<YourCustomObject__c> createHistoryRecords(
    Integer numRecords
  ) {
    List<YourCustomObject__c> historyRecords = new List<YourCustomObject__c>();
    for (Integer i = 0; i < numRecords; i++) {
      historyRecords.add(
        new YourCustomObject__c()
        // Populate required fields here
      );
    }
    insert historyRecords; // Insert the custom object records
    return historyRecords;
  }

  public static List<YourCustomObject__c> createCustomObjects(
    Integer numRecords
  ) {
    List<YourCustomObject__c> customObjects = new List<YourCustomObject__c>();
    for (Integer i = 0; i < numRecords; i++) {
      customObjects.add(
        new YourCustomObject__c()
        // Populate required fields here
      );
    }
    insert customObjects; // Insert the custom object records
    return customObjects;
  }
}