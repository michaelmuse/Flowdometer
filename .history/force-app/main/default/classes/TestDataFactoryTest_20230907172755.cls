@isTest
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

    // Add similar test methods for other TestDataFactory methods
}
