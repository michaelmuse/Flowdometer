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
    static void testGrantFieldAccessWithDmlMissingPermissionSet() {
        // The Metadata API FLS callout path was retired (Build Plan A.2).
        // FLS now lands on the unmanaged Flowdometer_Dynamic_FLS permission set
        // via native DML. When that PS is absent (as in a bare test context),
        // the method returns false gracefully without throwing.
        Test.startTest();
        Boolean result = MetaDataUtilityCls.grantFieldAccessWithDml(
            'Test_Object__c',
            'Test_Field__c'
        );
        Test.stopTest();

        System.assertEquals(false, result,
            'Grant should fail gracefully when the dynamic FLS permission set is absent');
    }

    @IsTest
    static void testGrantFieldAccessWithDmlRejectsBlankInput() {
        Test.startTest();
        Boolean blankObjectResult = MetaDataUtilityCls.grantFieldAccessWithDml('', 'Opportunity__c');
        Boolean blankFieldResult = MetaDataUtilityCls.grantFieldAccessWithDml('Flow__c', '');
        Test.stopTest();

        System.assertEquals(false, blankObjectResult, 'Blank object names should not attempt setup DML');
        System.assertEquals(false, blankFieldResult, 'Blank field names should not attempt setup DML');
    }

    @IsTest
    static void testGrantFieldAccessWithDmlOnUnmanagedPermissionSet() {
        // FLS now lands on the unmanaged Flowdometer_Dynamic_FLS permission set
        // (Build Plan A). Create it, then grant an existing packaged field on the
        // managed Flow__c object - the grant should succeed via native DML.
        //
        // Pass the OBJECT api name exactly as real callers do: via describe
        // (Flow__c.SObjectType.getDescribe().getName()), which yields the
        // namespaced name in a namespaced org. grantFieldAccessWithDml must NOT
        // re-namespace the object itself; doing so previously broke FLS for
        // subscriber custom objects (QA_Tracked__c -> Flowdometer__QA_Tracked__c).
        // Resolve-by-name (mirrors the reconciler's ensureUnmanagedPermissionSet):
        // the runtime unmanaged PS can survive a prior test's rollback in the
        // packaging org via async PSG recalculation, so a blind insert would hit
        // DUPLICATE_MASTER_LABEL. Reuse it if present, otherwise create it.
        List<PermissionSet> existingPs = [
            SELECT Id FROM PermissionSet WHERE Name = 'Flowdometer_Dynamic_FLS' LIMIT 1
        ];
        PermissionSet ps;
        if (existingPs.isEmpty()) {
            ps = new PermissionSet(
                Name = 'Flowdometer_Dynamic_FLS',
                Label = 'Flowdometer Dynamic FLS'
            );
            insert ps;
        } else {
            ps = existingPs[0];
        }

        String flowObjectApi = Flow__c.SObjectType.getDescribe().getName();

        Test.startTest();
        Boolean result = MetaDataUtilityCls.grantFieldAccessWithDml(flowObjectApi, 'Opportunity__c');
        Test.stopTest();

        System.assertEquals(true, result,
            'Granting an existing field on the unmanaged permission set should succeed');

        List<FieldPermissions> fps = [
            SELECT Id, SobjectType FROM FieldPermissions WHERE ParentId = :ps.Id
        ];
        System.assert(!fps.isEmpty(),
            'A FieldPermissions record should exist on the unmanaged permission set');
        System.assertEquals(flowObjectApi, fps[0].SobjectType,
            'FieldPermissions must use the object api name as supplied by the caller (not re-namespaced)');
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
            'Flow__c',
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

    // ========== Label -> API Name Sanitization Tests ==========

    @IsTest
    static void testConvertLabeltoAPIName() {
        Test.startTest();

        // Spaces and punctuation collapse to underscores, with __c appended
        System.assertEquals(
            'Stage_Name__c',
            MetaDataUtilityCls.convertLabeltoAPIName('Stage Name'),
            'Spaces should become underscores and __c appended'
        );
        System.assertEquals(
            'Close_Date__2_0___c',
            MetaDataUtilityCls.convertLabeltoAPIName('Close-Date (2.0)'),
            'Each non-alphanumeric character becomes its own underscore'
        );
        // Already-clean alphanumeric label just gets the suffix
        System.assertEquals(
            'Amount__c',
            MetaDataUtilityCls.convertLabeltoAPIName('Amount'),
            'Clean label should simply receive the __c suffix'
        );

        Test.stopTest();
    }

    /**
     * doesFieldExist must recognize the package's own shipped fields by their
     * UNQUALIFIED name: in an installed org the field is namespace-qualified
     * (Flowdometer__Opportunity__c), and missing it made the product create an
     * unmanaged duplicate of its own lookup (confirmed 2026-06-10). The
     * unqualified name must resolve in both the packaging org (where the field
     * is literally Opportunity__c) and namespaced contexts (via the qualified
     * candidate).
     */
    @IsTest
    static void testDoesFieldExistResolvesNamespacedShippedField() {
        String flowApi = Flow__c.SObjectType.getDescribe().getName();

        System.assert(
            MetaDataUtilityCls.doesFieldExist(flowApi, 'Opportunity__c'),
            'Shipped Flow__c Opportunity lookup must be found by its unqualified name'
        );
        System.assert(
            MetaDataUtilityCls.doesFieldExist(flowApi, 'Goal__c'),
            'Shipped Flow__c.Goal__c must be found by its unqualified name'
        );
        System.assert(
            !MetaDataUtilityCls.doesFieldExist(flowApi, 'No_Such_Field__c'),
            'A field that exists in neither form must not be found'
        );
    }

    /**
     * Relationship names for dynamic lookups must be unique on the referenced
     * object (Flow__c for all forward lookups), so they are qualified with the
     * target object. Same-labeled tracked fields on different objects must
     * yield DIFFERENT relationship names (the same-label collision bug).
     */
    @IsTest
    static void testBuildRelationshipName() {
        Test.startTest();

        String onCase = MetaDataUtilityCls.buildRelationshipName('Case', 'Status_Flow__c');
        String onCustom = MetaDataUtilityCls.buildRelationshipName('QA_Tracked__c', 'Status_Flow__c');

        System.assertEquals('Case_Status_Flow', onCase,
            'Relationship name should be object-qualified with the __c suffix stripped');
        System.assertEquals('QA_Tracked_Status_Flow', onCustom,
            'Custom-object __c suffix should be stripped and underscores collapsed');
        System.assertNotEquals(onCase, onCustom,
            'Same-labeled fields on different objects must not collide');

        // Namespaced object (package build org): no consecutive underscores
        String onNamespaced = MetaDataUtilityCls.buildRelationshipName(
            'Flowdometer__Flow__c', 'QA_Tracked__c');
        System.assertEquals('Flowdometer_Flow_QA_Tracked', onNamespaced,
            'Namespace separator should collapse to a single underscore');

        // Length cap: never exceed 40 chars, never end with an underscore
        String longName = MetaDataUtilityCls.buildRelationshipName(
            'A_Very_Long_Custom_Object_Name_Here__c',
            'An_Equally_Long_Field_Name_Flow__c');
        System.assert(longName.length() <= 40,
            'Relationship name must be capped at 40 chars, got: ' + longName);
        System.assert(!longName.endsWith('_'),
            'Relationship name must not end with an underscore: ' + longName);
        System.assert(!longName.contains('__'),
            'Relationship name must not contain consecutive underscores: ' + longName);

        Test.stopTest();
    }
}