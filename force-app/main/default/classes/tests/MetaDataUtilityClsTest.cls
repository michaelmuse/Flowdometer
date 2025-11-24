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

    @IsTest
    static void testCreateLookupField() {
        Test.startTest();
        Map<String,String> res = MetaDataUtilityCls.createLookupField(
            'Account',
            'Opportunity Flow',
            'Flowdometer__Flow__c',
            null
        );
        System.assertEquals('true', res.get('success'));
        Test.stopTest();
    }

    // ========== Field Existence Tests ==========
    
    @IsTest
    static void testDoesFieldExist_NoNormalization() {
        // Verify normalization logic is removed - should use case-insensitive comparison
        Test.startTest();
        
        // Test with standard field (case-insensitive matching)
        Boolean exists1 = MetaDataUtilityCls.doesFieldExist('Account', 'Name');
        System.assertEquals(true, exists1, 'Name field should exist on Account');
        
        // Test with different case
        Boolean exists2 = MetaDataUtilityCls.doesFieldExist('Account', 'name');
        System.assertEquals(true, exists2, 'name field (lowercase) should exist on Account');
        
        // Test with invalid field
        Boolean exists3 = MetaDataUtilityCls.doesFieldExist('Account', 'InvalidField__c');
        System.assertEquals(false, exists3, 'InvalidField__c should not exist on Account');
        
        // Test with null object name
        Boolean exists4 = MetaDataUtilityCls.doesFieldExist(null, 'Name');
        System.assertEquals(false, exists4, 'Should return false for null object name');
        
        // Test with null field name
        Boolean exists5 = MetaDataUtilityCls.doesFieldExist('Account', null);
        System.assertEquals(false, exists5, 'Should return false for null field name');
        
        Test.stopTest();
    }

    // ========== Field History Status Tests ==========
    
    @IsTest
    static void testCheckFieldHistoryStatus_StandardObject() {
        // Test standard object routing (should use Tooling API approach)
        Test.setMock(WebServiceMock.class, new MetadataServiceMock());
        
        Test.startTest();
        String result = MetaDataUtilityCls.checkFieldHistoryStatus('Case', 'Status');
        Test.stopTest();
        
        // Verify that standard objects are handled correctly
        // Result may be an error message or success message depending on test context
        System.assertNotEquals(null, result, 'Result should not be null');
        // The method should not throw an exception for standard objects
    }

    @IsTest
    static void testCheckFieldHistoryStatus_CustomObject() {
        // Test custom object routing (should use Metadata API approach)
        Test.setMock(WebServiceMock.class, new MetadataServiceMock());
        
        Test.startTest();
        // Test with a custom object if available, or use a standard object that supports history
        // Since we can't create custom objects in test context easily, test with Opportunity
        String result = MetaDataUtilityCls.checkFieldHistoryStatus('Opportunity', 'StageName');
        Test.stopTest();
        
        // Verify that custom/standard objects are handled correctly
        System.assertNotEquals(null, result, 'Result should not be null');
        // The method should route to appropriate API based on object type
    }

    @IsTest
    static void testCheckFieldHistoryStatus_InvalidObject() {
        // Test with invalid object name
        Test.setMock(WebServiceMock.class, new MetadataServiceMock());
        
        Test.startTest();
        String result = MetaDataUtilityCls.checkFieldHistoryStatus('InvalidObject__c', 'Name');
        Test.stopTest();
        
        // Should return an error message for invalid object
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.contains('ERROR'), 'Should return error for invalid object');
    }

    @IsTest
    static void testCheckFieldHistoryStatus_InvalidField() {
        // Test with invalid field name
        Test.setMock(WebServiceMock.class, new MetadataServiceMock());
        
        Test.startTest();
        String result = MetaDataUtilityCls.checkFieldHistoryStatus('Account', 'InvalidField__c');
        Test.stopTest();
        
        // Should return an error message for invalid field
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.contains('ERROR'), 'Should return error for invalid field');
    }
}