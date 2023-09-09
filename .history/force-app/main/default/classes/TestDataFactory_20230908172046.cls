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

    3. createlistenerConfigRec
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
        stageName='Prospecting',
        CloseDate=System.today(),
        AccountId=parentId
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

  public static Flowdometer__Listener__c createlistenerConfigRec(
    DateTime lastExecutionOn,
    Boolean insertRecord
  ) {
    Flowdometer__Listener__c listenerConfigRec = new Flowdometer__Listener__c(
      Flowdometer__Object_Name__c = 'Opportunity',
      Flowdometer__Field_To_Track__c = 'stageName',
      Flowdometer__TerminalStage__c = 'IsWon',
      Flowdometer__Last_Execution_On__c = lastExecutionOn
    );

    if (insertRecord) {
      insert listenerConfigRec;
    }

    return listenerConfigRec;
  }

  public static Opportunity createOpportunity(String stageName) {
      Opportunity opp = new Opportunity(
          Name = 'Test Opportunity',
          StageName = stageName,  // Use the parameter
          CloseDate = Date.today().addDays(10)
      );
      insert opp;
      return opp;
  }

  public static List<Opportunity> createOpportunityHistoryRecords(Integer numRecords, String stageName) {
      List<Opportunity> historyRecords = new List<Opportunity>();
      for (Integer i = 0; i < numRecords; i++) {
          historyRecords.add(
              new Opportunity(
                  Name = 'Test Opportunity ' + i,
                  stageName = stageName, // Use the provided stageName parameter
                  CloseDate = Date.today().addDays(10)
              )
          );
      }
      insert historyRecords; // Insert the Opportunity records
      return historyRecords;
  }


  public static List<Flowdometer__Flow__c> createCustomObjects(Integer numRecords) {
      List<Flowdometer__Flow__c> customObjects = new List<Flowdometer__Flow__c>();
      for (Integer i = 0; i < numRecords; i++) {
          customObjects.add(new Flowdometer__Flow__c());
      }
      insert customObjects; // Insert the Flowdometer__Flow__c records
      return customObjects;
  }

}
