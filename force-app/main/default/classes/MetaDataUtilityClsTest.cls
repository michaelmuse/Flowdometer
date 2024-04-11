@IsTest
public class MetaDataUtilityClsTest
{
    @IsTest
    static void testGetLookupField()
    {
        Test.startTest();
        
        // Call the method
        MetaDataUtilityCls.setLookupFieldMaps('Account');
        
        // Verify the result
        System.assertNotEquals(null, MetaDataUtilityCls.lookUpAPINameMap);
        System.assertNotEquals(null, MetaDataUtilityCls.relatedLookupMap);
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGetSObjectFields()
    {
        Test.startTest();
        
        // Call the method
        Map<String, String> result = MetaDataUtilityCls.getSObjectFields('Account');
        
        // Verify the result
        System.assertNotEquals(null, result);
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGetAllSObjectsInOrg()
    {
        Test.startTest();
        
        // Call the method
        Map<String, String> result = MetaDataUtilityCls.getAllSObjectsInOrg();
        
        // Verify the result
        System.assertNotEquals(null, result);
        
        Test.stopTest();
    }
    
    @IsTest
    static void testCheckFieldHistoryStatusOnCase()
    {
        // Null Web Service mock implementation
        System.Test.setMock(WebServiceMock.class, new WebServiceMockImpl());
        // Only required to workaround a current code coverage bug in the platform
        MetadataService metaDataService = new MetadataService();
        // Invoke operations     
        Test.startTest();
        MetadataService.MetadataPort metaDataPort = new MetadataService.MetadataPort();
        String fieldHistoryStatus = MetaDataUtilityCls.checkFieldHistoryStatus('Case', 'Status');
        Test.stopTest();
    }
    
    @IsTest
    static void testCreateListenerRecord()
    {
        Test.startTest();
        
        // Create test data
        Flowdometer__Listener__c newRecord = new Flowdometer__Listener__c();
        newRecord.Name = 'Test Listener';
        newRecord.Flowdometer__Last_Execution_On__c = Datetime.now();
        
        // Call the method
        String recordId = MetaDataUtilityCls.createListenerRecord(newRecord);
        
        // Verify the result
        System.assertNotEquals(null, recordId);
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGrantFieldEditAccessWithMockResponse()
    {
        // Null Web Service mock implementation
        System.Test.setMock(WebServiceMock.class, new WebServiceMockImpl());
        
        Test.startTest();
        MetaDataUtilityCls.grantFieldEditAccess('Test_Object__c', 'Test_Field__c'); Test.stopTest();
    
    }
    
    @IsTest
    static void testcheckFieldHistoryStatusOnOpportunity()
    {
        // Null Web Service mock implementation
        System.Test.setMock(WebServiceMock.class, new WebServiceMockImpl());
        // Only required to workaround a current code coverage bug in the platform
        MetadataService metaDataService = new MetadataService();
        // Invoke operations     
        Test.startTest();
        MetadataService.MetadataPort metaDataPort = new MetadataService.MetadataPort();
        String fieldHistoryStatus = MetaDataUtilityCls.checkFieldHistoryStatus('Opportunity', 'StageName');
        Test.stopTest();
    }
    
    private class WebServiceMockImpl implements WebServiceMock
    {
        public void doInvoke(
            Object stub, Object request, Map<String, Object> response,
            String endpoint, String soapAction, String requestName,
            String responseNS, String responseName, String responseType)
        {
            if (request instanceof MetadataService.retrieve_element)
                response.put('response_x', new MetadataService.retrieveResponse_element());
            else if (request instanceof MetadataService.checkDeployStatus_element)
                response.put('response_x', new MetadataService.checkDeployStatusResponse_element());
            else if (request instanceof MetadataService.listMetadata_element)
                response.put('response_x', new MetadataService.listMetadataResponse_element());
            else if (request instanceof MetadataService.checkRetrieveStatus_element)
                response.put('response_x', new MetadataService.checkRetrieveStatusResponse_element());
            else if (request instanceof MetadataService.describeMetadata_element)
                response.put('response_x', new MetadataService.describeMetadataResponse_element());
            else if (request instanceof MetadataService.deploy_element)
                response.put('response_x', new MetadataService.deployResponse_element());
            else if (request instanceof MetadataService.updateMetadata_element)
                response.put('response_x', new MetadataService.updateMetadataResponse_element());
            else if (request instanceof MetadataService.renameMetadata_element)
                response.put('response_x', new MetadataService.renameMetadataResponse_element());
            else if (request instanceof MetadataService.cancelDeploy_element)
                response.put('response_x', new MetadataService.cancelDeployResponse_element());
            else if (request instanceof MetadataService.deleteMetadata_element)
                response.put('response_x', new MetadataService.deleteMetadataResponse_element());
            else if (request instanceof MetadataService.upsertMetadata_element)
                response.put('response_x', new MetadataService.upsertMetadataResponse_element());
            else if (request instanceof MetadataService.createMetadata_element)
                response.put('response_x', new MetadataService.createMetadataResponse_element());
            else if (request instanceof MetadataService.deployRecentValidation_element)
                response.put('response_x', new MetadataService.deployRecentValidationResponse_element());
            else if (request instanceof MetadataService.describeValueType_element)
                response.put('response_x', new MetadataService.describeValueTypeResponse_element());
            else if (request instanceof MetadataService.checkRetrieveStatus_element)
                response.put('response_x', new MetadataService.checkRetrieveStatusResponse_element());
            return;
        }
    }
}