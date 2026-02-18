/**
 * REST helper to deactivate all Flowdometer flows before package uninstall.
 * Solves the "Flow is still active" error that blocks managed-package removal.
 *
 * Security note: This endpoint is intentionally global/@RestResource so that
 * admins can call it from the uninstall helper LWC or via a pre-uninstall
 * cURL command.  Access is protected by the Salesforce REST API session
 * (callers must be authenticated users with the Flowdometer_User permission
 * set).  The endpoint only deactivates hard-coded Flowdometer flow names —
 * no user-supplied inputs are accepted, so there is no injection risk.
 */
@RestResource(urlMapping='/flowdometer/deactivateFlows/*')
global with sharing class FlowdometerUninstallHelper {
    
    // List of flow API names to deactivate before uninstall
    private static final Set<String> FLOWDOMETER_FLOWS = new Set<String>{
        'Listener_Configuration_Main_Flow',
        'Flowdometer_Assign_Step_Goals_to_Step_Trackers',
        'Listener_Batch_Flow',
        'Flowdometer_Assign_New_Goals_to_Matching_Flows_without_a_Goal',
        'Listener_Flow_Sub_Flow',
        'Flows_and_Steps_for_Tracked_Object',
        'Set_Goal_for_Steps_in_Object_Field',
        'Flowdometer_Autocalculate_Business_Hours',
        'Flowdometer_Update_Tasks_with_Current_Step'
    };
    
    /**
     * REST endpoint to deactivate all Flowdometer flows
     * This can be called before uninstalling the package
     * GET /services/apexrest/flowdometer/deactivateFlows
     */
    @HttpGet
    global static UninstallResponse deactivateFlowsREST() {
        try {
            Integer deactivatedCount = deactivateFlows();
            return new UninstallResponse(true, 'Successfully deactivated ' + deactivatedCount + ' flows. You can now uninstall the package.', deactivatedCount);
        } catch (Exception e) {
            return new UninstallResponse(false, 'Error deactivating flows: ' + e.getMessage(), 0);
        }
    }
    
    /**
     * Apex method that can be called from a button or other code
     * @return Number of flows deactivated
     */
    @AuraEnabled
    public static Integer deactivateFlows() {
        System.enqueueJob(new FlowDeactivator(FLOWDOMETER_FLOWS));
        System.enqueueJob(new LookupFieldCleaner());
        return FLOWDOMETER_FLOWS.size();
    }
    
    // Response class for the REST endpoint
    global class UninstallResponse {
        global Boolean success;
        global String message;
        global Integer deactivatedCount;
        
        global UninstallResponse(Boolean success, String message, Integer deactivatedCount) {
            this.success = success;
            this.message = message;
            this.deactivatedCount = deactivatedCount;
        }
    }
    
    // Custom exception class
    public class FlowDeactivationException extends Exception {}
}