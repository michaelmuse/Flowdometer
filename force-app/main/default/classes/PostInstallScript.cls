/**
 * Post-install script for the Flowdometer package.
 *
 * Permission assignment intentionally happens NOT here. Bulk-assigning a
 * permission set to all users at install time is a Security Review risk and was
 * removed (Build Plan item C). Permission infrastructure - the unmanaged
 * Flowdometer_Dynamic_FLS permission set and the Flowdometer_Access permission
 * set group - is created and continuously reconciled by
 * FlowdometerPermissionReconciler from the post-auth setup gate (item A.0), and
 * the PSG is assigned only to administrators (capability-based detection).
 *
 * InstallContext executes in an elevated platform context by design; this is
 * intentional and documented by Salesforce. This handler is retained as the
 * package's registered InstallHandler but performs no assignment.
 */
public with sharing class PostInstallScript implements InstallHandler {

    public void onInstall(InstallContext context) {
        // No-op by design. See class header: assignment moved to the setup gate
        // reconciler to avoid unconditional bulk permission-set assignment.
        System.debug(LoggingLevel.INFO,
            'Flowdometer PostInstallScript ran; permission setup is handled by the setup gate.');
    }
}
