@isTest(SeeAllData=false)
public class TestDataFactoryTest {

    @isTest
    static void testCreateOpportunityHistoryRecords() {
        // Create a test Opportunity record
        Opportunity testOpportunity = TestDataFactory.createOpportunity('Test Stage');
        insert testOpportunity;

        // Call the createOpportunityHistoryRecords method
        List<OpportunityFieldHistory> historyRecords = TestDataFactory.createOpportunityHistoryRecords(
            testOpportunity.Id,
            'Test Field',
            5  // Number of history records to create
        );

        // Assert that the history records were created
        System.assertEquals(5, historyRecords.size());
    }

    @isTest
    static void testCreateCaseHistoryRecords() {
        // Create a test Case record
        Case testCase = new Case(
            Subject = 'Test Case',
            Status = 'Open'
        );
        insert testCase;

        // Call the createCaseHistoryRecords method
        List<CaseHistory> historyRecords = TestDataFactory.createCaseHistoryRecords(
            testCase.Id,
            'Test Field',
            3  // Number of history records to create
        );

        // Assert that the history records were created
        System.assertEquals(3, historyRecords.size());
    }

    @isTest
    static void testCreateListenerConfig() {
        // Call the createListenerConfig method
        Flowdometer__Listener__c listenerConfig = TestDataFactory.createListenerConfig(
            DateTime.now(),
            true  // Insert the record
        );

        // Assert that the listenerConfig was created
        System.assertNotEquals(null, listenerConfig.Id);

        // Delete the created record to clean up after the test
        delete listenerConfig;
    }


    @isTest
    static void testCreateOpportunity() {
        // Call the createOpportunity method
        Opportunity testOpportunity = TestDataFactory.createOpportunity('Test Stage');

        // Assert that the Opportunity was created
        System.assertNotEquals(null, testOpportunity.Id);
    }

    @isTest
    static void testCreateHistoryRecords() {
        // Call the createHistoryRecords method
        List<YourCustomObject__c> historyRecords = TestDataFactory.createHistoryRecords(3); // Create 3 records

        // Assert that the history records were created
        System.assertEquals(3, historyRecords.size());

        // Optionally, you can delete the created records here to clean up after the test
        delete historyRecords;
    }

    @isTest
    static void testCreateCustomObjects() {
        // Call the createCustomObjects method
        List<YourCustomObject__c> customObjects = TestDataFactory.createCustomObjects(4); // Create 4 records

        // Assert that the custom objects were created
        System.assertEquals(4, customObjects.size());

        // Optionally, you can delete the created records here to clean up after the test
        delete customObjects;
    }
}
