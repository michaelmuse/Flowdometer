/**
 * Post-install script for Flowdometer package.
 * Assigns the Flowdometer_User permission set to all active users.
 * OAuth setup happens when admin clicks "Complete Setup" in the LWC.
 */
public with sharing class PostInstallScript implements InstallHandler {
    private static final String PERMISSION_SET_NAME = 'Flowdometer_User';

    public void onInstall(InstallContext context) {
        try {
            assignPermissionSet();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'PostInstallScript PermSet error: ' + e.getMessage());
        }
    }

    /**
     * Assigns the Flowdometer_User permission set to all active users who
     * don't already have it. Uses partial-success DML so one user's failure
     * doesn't block the rest.
     */
    private void assignPermissionSet() {
        List<PermissionSet> permissionSets = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = :PERMISSION_SET_NAME
            LIMIT 1
        ];

        if (permissionSets.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'Flowdometer permission set not found: ' + PERMISSION_SET_NAME);
            return;
        }

        Id psId = permissionSets[0].Id;

        List<User> activeUsers = [
            SELECT Id
            FROM User
            WHERE IsActive = true
        ];

        if (activeUsers.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'No active users found for permission set assignment');
            return;
        }

        // Collect IDs of users who already have the assignment
        Set<Id> alreadyAssigned = new Set<Id>();
        for (PermissionSetAssignment psa : [
            SELECT AssigneeId
            FROM PermissionSetAssignment
            WHERE PermissionSetId = :psId
              AND AssigneeId IN :activeUsers
        ]) {
            alreadyAssigned.add(psa.AssigneeId);
        }

        // Build new assignments only for users without one
        List<PermissionSetAssignment> newAssignments = new List<PermissionSetAssignment>();
        for (User u : activeUsers) {
            if (!alreadyAssigned.contains(u.Id)) {
                newAssignments.add(new PermissionSetAssignment(
                    PermissionSetId = psId,
                    AssigneeId = u.Id
                ));
            }
        }

        if (newAssignments.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'All active users already have the Flowdometer permission set');
            return;
        }

        Database.SaveResult[] results = Database.insert(newAssignments, false);
        Integer successCount = 0;
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                successCount++;
            } else {
                for (Database.Error err : results[i].getErrors()) {
                    System.debug(
                        LoggingLevel.ERROR,
                        'Failed to assign permission set to user ' +
                        newAssignments[i].AssigneeId + ': ' + err.getMessage()
                    );
                }
            }
        }
        System.debug(
            LoggingLevel.INFO,
            'Assigned Flowdometer permission set to ' + successCount +
            ' of ' + newAssignments.size() + ' users'
        );
    }
}
