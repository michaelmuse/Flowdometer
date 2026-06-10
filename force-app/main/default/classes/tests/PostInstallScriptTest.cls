/**
 * Tests for PostInstallScript.
 *
 * After Build Plan item C, the post-install handler no longer assigns any
 * permission set. This verifies the handler runs as a clean no-op and that no
 * bulk permission-set assignment is created at install time.
 */
@IsTest
private class PostInstallScriptTest {

    @IsTest
    static void onInstallIsNoOp() {
        Integer assignmentsBefore = [SELECT COUNT() FROM PermissionSetAssignment];

        Test.startTest();
        Test.testInstall(new PostInstallScript(), null);
        Test.stopTest();

        Integer assignmentsAfter = [SELECT COUNT() FROM PermissionSetAssignment];
        System.assertEquals(assignmentsBefore, assignmentsAfter,
            'PostInstallScript must not create any permission-set assignments');
    }
}
