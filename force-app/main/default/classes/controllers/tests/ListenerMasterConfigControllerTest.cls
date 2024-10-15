/**
 * @description Unit tests for ListenerMasterConfigurationController
 */
@IsTest
private class ListenerMasterConfigControllerTest {
    @IsTest
    static void testGetAllSObjectsInOrg() {
        Map<String, String> result;

        Test.startTest();
        {
            result = ListenerMasterConfigurationController.getAllSObjectsInOrg();
        }
        Test.stopTest();

        Assert.isTrue(result.containsKey('Account'));
        Assert.isFalse(result.containsKey('AccountShare'));
    }

    @IsTest
    static void testGetSObjectFields() {
        Map<String, String> result;

        Test.startTest();
        {
            result = ListenerMasterConfigurationController.getSObjectFields('Account');
        }
        Test.stopTest();

        Assert.isTrue(result.containsKey('Name'));
    }

    @IsTest
    static void testCheckFieldHistoryStatus() {
        String result;

        Test.setMock(WebServiceMock.class, new MetadataServiceMock());
        Test.startTest();
        {
            result = ListenerMasterConfigurationController.checkFieldHistoryStatus(
                    'Case',
                    'Status'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testCreateListenerRecord() {
        Flowdometer__Listener__c newRecord = new Flowdometer__Listener__c();
        newRecord.Name = 'Test Listener';
        newRecord.Flowdometer__Last_Execution_On__c = Datetime.now();

        Id result;
        Test.startTest();
        {
            result = (Id) ListenerMasterConfigurationController.createListenerRecord(newRecord);
        }
        Test.stopTest();

        Assert.areEqual(Listener__c.SObjectType, result.getSobjectType());
    }
}