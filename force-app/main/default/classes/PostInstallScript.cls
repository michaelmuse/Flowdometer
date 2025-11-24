/**
 * Post-install script for Flowdometer package
 * Automatically assigns the Flowdometer permission set to all active users upon package installation
 */
public class PostInstallScript implements InstallHandler {
    
    private static final String PERMISSION_SET_NAME = 'Flowdometer__Flowdometer_User';
    
    /**
     * Called when the package is installed
     * @param context Installation context containing organization and installer information
     */
    public void onInstall(InstallContext context) {
        try {
            // Query for the Flowdometer permission set
            List<PermissionSet> permissionSets = [
                SELECT Id, Name 
                FROM PermissionSet 
                WHERE Name = :PERMISSION_SET_NAME 
                LIMIT 1
            ];
            
            if (permissionSets.isEmpty()) {
                System.debug(LoggingLevel.WARN, 'Flowdometer permission set not found: ' + PERMISSION_SET_NAME);
                return;
            }
            
            PermissionSet ps = permissionSets[0];
            
            // Get all active users
            List<User> activeUsers = [
                SELECT Id, Username, IsActive 
                FROM User 
                WHERE IsActive = true
            ];
            
            if (activeUsers.isEmpty()) {
                System.debug(LoggingLevel.INFO, 'No active users found to assign permission set');
                return;
            }
            
            // Check existing assignments to avoid duplicates
            Set<Id> existingAssigneeIds = new Set<Id>();
            List<PermissionSetAssignment> existingAssignments = [
                SELECT AssigneeId 
                FROM PermissionSetAssignment 
                WHERE PermissionSetId = :ps.Id 
                AND AssigneeId IN :activeUsers
            ];
            
            for (PermissionSetAssignment psa : existingAssignments) {
                existingAssigneeIds.add(psa.AssigneeId);
            }
            
            // Create permission set assignments for users who don't already have it
            List<PermissionSetAssignment> newAssignments = new List<PermissionSetAssignment>();
            for (User u : activeUsers) {
                if (!existingAssigneeIds.contains(u.Id)) {
                    PermissionSetAssignment psa = new PermissionSetAssignment();
                    psa.PermissionSetId = ps.Id;
                    psa.AssigneeId = u.Id;
                    newAssignments.add(psa);
                }
            }
            
            // Insert new assignments
            if (!newAssignments.isEmpty()) {
                insert newAssignments;
                System.debug(LoggingLevel.INFO, 'Assigned Flowdometer permission set to ' + newAssignments.size() + ' active users');
            } else {
                System.debug(LoggingLevel.INFO, 'All active users already have the Flowdometer permission set assigned');
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in PostInstallScript.onInstall: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            // Don't throw - allow installation to complete even if permission set assignment fails
        }
    }
}