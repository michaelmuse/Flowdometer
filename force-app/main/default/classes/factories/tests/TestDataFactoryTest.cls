@IsTest
public class TestDataFactoryTest {
    @IsTest
    static void testCreateOpportunityHistoryRecords() {
        // Initialize your parameters
        Integer numRecords = 5;
        String fieldName = 'StageName';

        // Call the createOpportunityHistoryRecords method with the new signature
        List<Opportunity> historyRecords = TestDataFactory.createOpportunityHistoryRecords(
            numRecords,
            fieldName
        );

        // Assert that the history records were created
        System.assertEquals(5, historyRecords.size());
    }

    @IsTest
    static void testCreateCase() {
        // Arrange
        String expectedSubject = 'Test Subject';
        String expectedStatus = 'New';

        // Act
        Case newCase = TestDataFactory.createCase(
            expectedSubject,
            expectedStatus
        );

        // Assert
        System.assertNotEquals(
            null,
            newCase.Id,
            'Case should be inserted and have an Id'
        );
        System.assertEquals(
            expectedSubject,
            newCase.Subject,
            'Case subject should match expected subject'
        );
        System.assertEquals(
            expectedStatus,
            newCase.Status,
            'Case status should match expected status'
        );
    }

    @IsTest
    static void testCreateListenerConfig() {
        // Define test data
        String objectName = 'Case';
        String fieldToTrack = 'Status';
        Datetime lastExecutionOn = Datetime.now();
        Boolean insertRecord = true;

        // Call the createListenerConfig method
        Flowdometer__Listener__c listenerConfig = TestDataFactory.createListenerConfig(
            objectName,
            fieldToTrack,
            lastExecutionOn,
            insertRecord
        );

        // Assert that the listenerConfig was created
        System.assertNotEquals(null, listenerConfig.Id);

        // Delete the created record to clean up after the test
        delete listenerConfig;
    }

    @IsTest
    static void testCreateOpportunity() {
        // Call the createOpportunity method and capture the result
        Opportunity testOpportunity = TestDataFactory.createOpportunity(
            'Test Opportunity',
            'Test Stage',
            Date.today()
        );

        // Assert that the Opportunity was created
        System.assertNotEquals(null, testOpportunity.Id);
    }

    @IsTest
    static void testCreateCustomObjects() {
        // Create custom objects using the TestDataFactory method
        Integer numRecords = 3; // Adjust the number of records as needed
        List<Flow__c> customObjects = TestDataFactory.createCustomObjects(
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
