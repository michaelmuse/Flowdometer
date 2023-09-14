//force-app\main\default\classes\TestDataFactory.cls (Data Factory class for Controller Tests)

/*   

TestDataFactory Class Method Summary:

    1. createOpportunityHistoryRecords
       - Parameters: 
         - Id parentId: The parent Opportunity Id
         - String field: The field name for history tracking
         - Integer numRecords: The number of history records to create
       - Returns: List<Opportunity>

    2. createCaseHistoryRecords
       - Parameters:
         - Id parentId: The parent Case Id
         - String field: The field name for history tracking
         - Integer numRecords: The number of history records to create
       - Returns: List<CaseHistory>

    3. createlistenerConfig
       - Parameters:
         - DateTime lastExecutionOn: The last execution time for the Listener
       - Returns: Listener__c

    4. createOpportunity
       - Parameters:
         - String stageName: The stage name for the Opportunity
       - Returns: Opportunity

    5. createHistoryRecords
       - Parameters:
         - Integer numRecords: The number of History__c records to create
       - Returns: List<History__c>

    6. createAndUpdateOpportunities
       - Parameters:
         - Id parentId: The parent Account Id
         - String field: The field name for history tracking
         - Integer numRecords: The number of Opportunities to create and update
       - Returns: List<Opportunity>

    7. createCustomObjects
       - Parameters:
         - Integer numRecords: The number of Flow__c records to create
       - Returns: List<Flow__c>
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
  
  public static Case createCase(String subject, String status) {
    Case newCase = new Case(
      Subject = subject,
      Status = status
    );
    insert newCase;
    return newCase;
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

  public static Listener__c createlistenerConfig(
    String objectName,
    String fieldToTrack,
    String terminalStage,
    DateTime lastExecutionOn,
    Boolean insertRecord
  ) {
    Listener__c listenerConfig = new Listener__c(
      Object_Name__c = objectName,
      Field_To_Track__c = fieldToTrack,
      TerminalStage__c = terminalStage,
      Last_Execution_On__c = lastExecutionOn
    );
  
    if (insertRecord) {
      insert listenerConfig;
    }
  
    return listenerConfig;
  }

  public static Opportunity createOpportunity(String name, String stageName, Date closeDate) {
    Opportunity opp = new Opportunity(
        Name = name,
        StageName = stageName,
        CloseDate = closeDate
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

  public static List<Flow__c> createCustomObjects(Integer numRecords) {
      List<Flow__c> customObjects = new List<Flow__c>();
      for (Integer i = 0; i < numRecords; i++) {
          customObjects.add(new Flow__c());
      }
      insert customObjects; // Insert the Flow__c records
      return customObjects;
  }

}