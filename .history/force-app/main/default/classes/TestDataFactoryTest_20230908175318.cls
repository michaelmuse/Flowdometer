@isTest
public class TestDataFactoryTest {
  @isTest
  static void testCreateOpportunityHistoryRecords() {
    // Initialize your parameters
    Integer numRecords = 5;
    String fieldName = 'StageName';

    // Call the createOpportunityHistoryRecords method with the new signature
    List<OpportunityFieldHistory> historyRecords = TestDataFactory.createOpportunityHistoryRecords(numRecords, fieldName);  // Capture the returned list

    // Assert that the history records were created
    System.assertEquals(5, historyRecords.size());
  }

  @isTest
  static void testCreateCaseHistoryRecords() {
      // Create a test Case record
      Case testCase = new Case(Subject = 'Test Case', Status = 'Open');
      insert testCase;

      // Call the createCaseHistoryRecords method
      List<CaseHistory> historyRecords = TestDataFactory.createCaseHistoryRecords(
          testCase.Id,  // Parent Case Id
          'Status',     // Field to track
          3             // Number of history records to create
      );

      // Assert that the history records were created
      System.assertEquals(3, historyRecords.size());
  }


  @isTest
  static void testCreatelistenerConfigRec() {
    // Call the createlistenerConfigRec method
    Flowdometer__Listener__c listenerConfigRec = TestDataFactory.createlistenerConfigRec(
      DateTime.now(),
      true // Insert the record
    );

    // Assert that the listenerConfigRec was created
    System.assertNotEquals(null, listenerConfigRec.Id);

    // Delete the created record to clean up after the test
    delete listenerConfigRec;
  }

  @isTest
  static void testCreateOpportunity() {
      // Call the createOpportunity method
      createOpportunity('Test Stage');
      
      // Assert that the Opportunity was created
      System.assertNotEquals(null, testOpportunity.Id);
  }


  @isTest
  static void testCreateCustomObjects() {
    // Create custom objects using the TestDataFactory method
    Integer numRecords = 3; // Adjust the number of records as needed
    List<Flowdometer__Flow__c> customObjects = TestDataFactory.createCustomObjects(
      numRecords
    );

    // Verify that the custom objects were created
    System.assertEquals(
      numRecords,
      customObjects.size(),
      'Number of custom objects created should match'
    );
      // Optionally, you can delete the created records here to clean up after the test
      delete customObjects;

  }

}
