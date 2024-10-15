@IsTest
public class MetaDataUtilityClsTest {
    @IsTest
    static void testGetLookupField() {
        Test.startTest();

        // Call the method
        MetaDataUtilityCls.setLookupFieldMaps('Account');

        // Verify the result
        System.assertNotEquals(null, MetaDataUtilityCls.lookUpAPINameMap);
        System.assertNotEquals(null, MetaDataUtilityCls.relatedLookupMap);

        Test.stopTest();
    }

    @IsTest
    static void testGetSObjectFields() {
        Test.startTest();

        // Call the method
        Map<String, String> result = MetaDataUtilityCls.getSObjectFields(
            'Account'
        );

        // Verify the result
        System.assertNotEquals(null, result);

        Test.stopTest();
    }

    @IsTest
    static void testGetAllSObjectsInOrg() {
        Test.startTest();

        // Call the method
        Map<String, String> result = MetaDataUtilityCls.getAllSObjectsInOrg();

        // Verify the result
        System.assertNotEquals(null, result);

        Test.stopTest();
    }

    @IsTest
    static void testCheckFieldHistoryStatusOnCase() {
        // Null Web Service mock implementation
        System.Test.setMock(WebServiceMock.class, new MetadataServiceMock());
        // Only required to workaround a current code coverage bug in the platform
        MetadataService metaDataService = new MetadataService();
        // Invoke operations
        Test.startTest();
        MetadataService.MetadataPort metaDataPort = new MetadataService.MetadataPort();
        String fieldHistoryStatus = MetaDataUtilityCls.checkFieldHistoryStatus(
            'Case',
            'Status'
        );
        Test.stopTest();
    }

    @IsTest
    static void testGrantFieldEditAccessWithMockResponse() {
        // Null Web Service mock implementation
        System.Test.setMock(WebServiceMock.class, new MetadataServiceMock());

        Test.startTest();
        MetaDataUtilityCls.grantFieldEditAccess(
            'Test_Object__c',
            'Test_Field__c'
        );
        Test.stopTest();
    }

    @IsTest
    static void testcheckFieldHistoryStatusOnOpportunity() {
        // Null Web Service mock implementation
        System.Test.setMock(WebServiceMock.class, new MetadataServiceMock());
        // Only required to workaround a current code coverage bug in the platform
        MetadataService metaDataService = new MetadataService();
        // Invoke operations
        Test.startTest();
        MetadataService.MetadataPort metaDataPort = new MetadataService.MetadataPort();
        String fieldHistoryStatus = MetaDataUtilityCls.checkFieldHistoryStatus(
            'Opportunity',
            'StageName'
        );
        Test.stopTest();
    }
}
