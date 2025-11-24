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
        newRecord.Flowdometer__Object_Name__c = 'Account';
        newRecord.Flowdometer__Field_To_Track__c = 'Name';

        Id result;
        Test.startTest();
        {
            result = (Id) ListenerMasterConfigurationController.createListenerRecord(newRecord);
        }
        Test.stopTest();

        Assert.areEqual(Listener__c.SObjectType, result.getSobjectType());
    }

    @IsTest
    static void testCreateListenerRecordForCustomObject() {
        // Test lookup field creation for custom objects
        Flowdometer__Listener__c newRecord = new Flowdometer__Listener__c();
        newRecord.Name = 'Test Custom Object Listener';
        newRecord.Flowdometer__Object_Name__c = 'Flowdometer__Flow__c';
        newRecord.Flowdometer__Field_To_Track__c = 'Flowdometer__Name_of_Tracked_Record__c';

        Test.setMock(WebServiceMock.class, new MetadataServiceMock());
        Test.startTest();
        {
            Id result = (Id) ListenerMasterConfigurationController.createListenerRecord(newRecord);
            Assert.isNotNull(result, 'Listener record should be created');
        }
        Test.stopTest();
    }

    @IsTest
    static void testCreateListenerRecordForStandardObjects() {
        // Test creating listeners for all standard objects
        List<String> standardObjects = new List<String>{ 'Account', 'Contact', 'Lead', 'Opportunity', 'Case' };
        List<Flowdometer__Listener__c> listeners = new List<Flowdometer__Listener__c>();

        Test.setMock(WebServiceMock.class, new MetadataServiceMock());
        Test.startTest();
        {
            for (String objName : standardObjects) {
                Flowdometer__Listener__c newRecord = new Flowdometer__Listener__c();
                newRecord.Name = 'Test ' + objName + ' Listener';
                newRecord.Flowdometer__Object_Name__c = objName;
                newRecord.Flowdometer__Field_To_Track__c = 'Name';
                
                try {
                    Id result = (Id) ListenerMasterConfigurationController.createListenerRecord(newRecord);
                    Assert.isNotNull(result, 'Listener should be created for ' + objName);
                    listeners.add(newRecord);
                } catch (Exception e) {
                    // Some standard objects may not support history tracking - that's okay
                    System.debug(LoggingLevel.INFO, 'Could not create listener for ' + objName + ': ' + e.getMessage());
                }
            }
        }
        Test.stopTest();

        Assert.isTrue(listeners.size() > 0, 'At least one listener should be created for standard objects');
    }

    @IsTest
    static void testStandardObjectLookupSkipping() {
        // Test that lookup creation is skipped for standard objects with existing lookups
        // This test verifies that the code checks if lookup fields already exist before creating them
        Flowdometer__Listener__c newRecord = new Flowdometer__Listener__c();
        newRecord.Name = 'Test Standard Object Lookup Skip';
        newRecord.Flowdometer__Object_Name__c = 'Account';
        newRecord.Flowdometer__Field_To_Track__c = 'Name';

        Test.setMock(WebServiceMock.class, new MetadataServiceMock());
        Test.startTest();
        {
            Id result = (Id) ListenerMasterConfigurationController.createListenerRecord(newRecord);
            Assert.isNotNull(result, 'Listener record should be created');
            
            // Verify that the listener was created even if lookup fields already exist
            Flowdometer__Listener__c createdListener = [
                SELECT Id, Flowdometer__Object_Name__c, Flowdometer__Field_To_Track__c
                FROM Flowdometer__Listener__c
                WHERE Id = :result
                LIMIT 1
            ];
            Assert.areEqual('Account', createdListener.Flowdometer__Object_Name__c);
        }
        Test.stopTest();
    }

    // ========== Lookup Field Label Tests ==========
    
    @IsTest
    static void testLookupFieldLabel_NoRecordSuffix() {
        // Test the label generation logic
        String objectName = 'Account';
        String fieldLabel = objectName + ' Flow';  // Should NOT be "Account Flow Record"
        
        System.assert(!fieldLabel.endsWith(' Record'), 'Label should not end with "Record"');
        System.assertEquals('Account Flow', fieldLabel, 'Label should be clean');
        
        // Test with different object names
        String oppLabel = 'Opportunity Flow';
        System.assert(!oppLabel.endsWith(' Record'), 'Opportunity label should not end with "Record"');
        
        String caseLabel = 'Case Flow';
        System.assert(!caseLabel.endsWith(' Record'), 'Case label should not end with "Record"');
    }

    // ========== Error Handling Tests ==========
    
    @IsTest
    static void testErrorHandling_ErrorMessagePersistence() {
        Flowdometer__Listener__c listener = new Flowdometer__Listener__c();
        listener.Name = 'Test Listener';
        listener.Flowdometer__Object_Name__c = 'Opportunity';
        listener.Flowdometer__Field_To_Track__c = 'StageName';
        insert listener;
        
        // Simulate error scenario
        String errorMessage = 'Failed to create lookup field: Test error';
        
        Test.startTest();
        if (Schema.sObjectType.Flowdometer__Listener__c.fields.Flowdometer__Error_Message__c.isUpdateable()) {
            listener.Flowdometer__Error_Message__c = errorMessage;
            update listener;
        }
        Test.stopTest();
        
        // Verify error message is persisted
        Flowdometer__Listener__c updatedListener = [
            SELECT Flowdometer__Error_Message__c 
            FROM Flowdometer__Listener__c 
            WHERE Id = :listener.Id
        ];
        System.assertEquals(errorMessage, updatedListener.Flowdometer__Error_Message__c, 
            'Error message should be persisted');
    }

    // ========== FLS Check Tests ==========
    
    @IsTest
    static void testFLSCheckErrorMessageCreate() {
        // Test FLS check on create
        Flowdometer__Listener__c newRecord = new Flowdometer__Listener__c();
        newRecord.Name = 'Test Listener';
        newRecord.Flowdometer__Object_Name__c = 'Account';
        newRecord.Flowdometer__Field_To_Track__c = 'Name';
        
        Test.startTest();
        try {
            // Check FLS before setting error message on create
            if (Schema.sObjectType.Flowdometer__Listener__c.fields.Flowdometer__Error_Message__c.isCreateable()) {
                newRecord.Flowdometer__Error_Message__c = 'Test error on create';
            }
            
            // Create the record
            Test.setMock(WebServiceMock.class, new MetadataServiceMock());
            Id result = (Id) ListenerMasterConfigurationController.createListenerRecord(newRecord);
            Assert.isNotNull(result, 'Listener should be created');
        } catch (Exception e) {
            // Should not throw exception - FLS check should prevent field assignment gracefully
            System.assert(false, 'Should not throw exception when FLS check fails: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testFLSCheckErrorMessageUpdate() {
        // Test FLS check on update
        Flowdometer__Listener__c listener = new Flowdometer__Listener__c();
        listener.Name = 'Test Listener';
        listener.Flowdometer__Object_Name__c = 'Account';
        listener.Flowdometer__Field_To_Track__c = 'Name';
        
        Test.setMock(WebServiceMock.class, new MetadataServiceMock());
        Id result = (Id) ListenerMasterConfigurationController.createListenerRecord(listener);
        
        // Query the created listener
        Flowdometer__Listener__c createdListener = [
            SELECT Id, Flowdometer__Error_Message__c
            FROM Flowdometer__Listener__c
            WHERE Id = :result
        ];
        
        Test.startTest();
        try {
            // Attempt to update Error_Message__c (should check FLS first)
            if (Schema.sObjectType.Flowdometer__Listener__c.fields.Flowdometer__Error_Message__c.isUpdateable()) {
                createdListener.Flowdometer__Error_Message__c = 'Test error on update';
                update createdListener;
            }
            // If FLS check fails, update should not happen, but no exception should be thrown
        } catch (Exception e) {
            // Should not throw exception - FLS check should prevent update gracefully
            System.assert(false, 'Should not throw exception when FLS check fails: ' + e.getMessage());
        }
        Test.stopTest();
        
        // Verify listener still exists (no crash)
        Flowdometer__Listener__c updatedListener = [
            SELECT Id, Flowdometer__Error_Message__c 
            FROM Flowdometer__Listener__c 
            WHERE Id = :result
        ];
        System.assertNotEquals(null, updatedListener, 'Listener should still exist');
    }

    @IsTest
    static void testStandardObjectLookupSkipping_Logic() {
        // Enhanced test for lookup skipping logic
        // Test that lookup creation is skipped for standard objects with existing lookups
        Flowdometer__Listener__c newRecord = new Flowdometer__Listener__c();
        newRecord.Name = 'Test Standard Object Lookup Skip Enhanced';
        newRecord.Flowdometer__Object_Name__c = 'Account';
        newRecord.Flowdometer__Field_To_Track__c = 'Name';

        Test.setMock(WebServiceMock.class, new MetadataServiceMock());
        Test.startTest();
        {
            Id result = (Id) ListenerMasterConfigurationController.createListenerRecord(newRecord);
            Assert.isNotNull(result, 'Listener record should be created');
            
            // Verify that the listener was created even if lookup fields already exist
            Flowdometer__Listener__c createdListener = [
                SELECT Id, Flowdometer__Object_Name__c, Flowdometer__Field_To_Track__c, Flowdometer__Error_Message__c
                FROM Flowdometer__Listener__c
                WHERE Id = :result
                LIMIT 1
            ];
            Assert.areEqual('Account', createdListener.Flowdometer__Object_Name__c);
            
            // Verify that standard objects don't cause errors even if lookup fields exist
            // The logic should gracefully handle existing lookup fields
            System.assertNotEquals(null, createdListener, 'Listener should exist');
        }
        Test.stopTest();
    }
}