/**
 * Tests for the Setup-Gate Reconciler (Build Plan A.0).
 *
 * Setup-object DML (PermissionSet / PermissionSetGroup / FieldPermissions /
 * PermissionSetAssignment) is wrapped in System.runAs to avoid MIXED_DML with
 * the non-setup test data, mirroring how the reconciler is invoked from the
 * setup gate by an administrator.
 */
@IsTest
private class FlowdometerPermissionReconcilerTest {

    @IsTest
    static void reconcileCreatesInfrastructure() {
        FlowdometerPermissionReconciler.ReconcileResult result;

        System.runAs(new User(Id = UserInfo.getUserId())) {
            // A listener exercises the FieldPermissions reconcile loop (both
            // directions). The reverse field (Flow__c.Opportunity__c) is a
            // packaged field, so its grant succeeds; the forward field may not
            // exist yet and fails its row silently (best-effort).
            insert new Listener__c(
                Object_Name__c = 'Opportunity',
                Field_To_Track__c = 'StageName'
            );

            Test.startTest();
            result = FlowdometerPermissionReconciler.reconcile();
            Test.stopTest();
        }

        System.assertEquals(true, result.success,
            'Reconcile should succeed for an admin running user: ' + result.message);

        List<PermissionSet> ps = [
            SELECT Id FROM PermissionSet
            WHERE Name = :FlowdometerPermissionReconciler.UNMANAGED_PS_NAME
        ];
        System.assertEquals(1, ps.size(), 'Unmanaged permission set should exist');

        List<PermissionSetGroup> psg = [
            SELECT Id FROM PermissionSetGroup
            WHERE DeveloperName = :FlowdometerPermissionReconciler.PSG_DEVNAME
        ];
        System.assertEquals(1, psg.size(), 'Permission set group should exist');

        List<PermissionSetGroupComponent> comps = [
            SELECT PermissionSetId FROM PermissionSetGroupComponent
            WHERE PermissionSetGroupId = :psg[0].Id
        ];
        System.assert(comps.size() >= 1,
            'PSG should bundle at least the unmanaged permission set component');
    }

    @IsTest
    static void reconcileIsIdempotent() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            FlowdometerPermissionReconciler.reconcile();

            Test.startTest();
            FlowdometerPermissionReconciler.ReconcileResult result =
                FlowdometerPermissionReconciler.reconcile();
            Test.stopTest();

            System.assertEquals(true, result.success, 'Second reconcile should also succeed');
        }

        List<PermissionSet> ps = [
            SELECT Id FROM PermissionSet
            WHERE Name = :FlowdometerPermissionReconciler.UNMANAGED_PS_NAME
        ];
        System.assertEquals(1, ps.size(), 'No duplicate unmanaged permission set on re-entry');

        List<PermissionSetGroup> psg = [
            SELECT Id FROM PermissionSetGroup
            WHERE DeveloperName = :FlowdometerPermissionReconciler.PSG_DEVNAME
        ];
        System.assertEquals(1, psg.size(), 'No duplicate PSG on re-entry');
    }

    @IsTest
    static void reconcileRestrictedUserHandledGracefully() {
        // Whether a restricted user can perform setup-object DML is
        // environment-dependent (profile permissions vary by org), so this does
        // NOT assert success/failure. It verifies the contract that matters:
        // reconcile never throws and always returns a user-facing result,
        // regardless of the caller's permissions.
        List<Profile> restrictedProfiles = [
            SELECT Id FROM Profile
            WHERE PermissionsModifyAllData = false AND UserType = 'Standard'
            LIMIT 1
        ];
        if (restrictedProfiles.isEmpty()) {
            return; // No suitable profile in this org; nothing to exercise.
        }

        User restrictedUser = new User(
            FirstName = 'Flowdometer',
            LastName = 'Restricted',
            Email = 'flowdometer.restricted@example.com.invalid',
            Username = 'flowdometer.restricted.' + DateTime.now().getTime() + '@example.com.invalid',
            Alias = 'fdrs',
            ProfileId = restrictedProfiles[0].Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert restrictedUser;

        FlowdometerPermissionReconciler.ReconcileResult result;
        System.runAs(restrictedUser) {
            Test.startTest();
            result = FlowdometerPermissionReconciler.reconcile();
            Test.stopTest();
        }

        System.assertNotEquals(null, result,
            'Reconcile must always return a result and never throw');
        System.assertNotEquals(null, result.message,
            'A user-facing message is always populated');
    }
}
