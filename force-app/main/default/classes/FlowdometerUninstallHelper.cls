/**
 * Pre-uninstall helper. A subscriber admin runs prepareForUninstall() from the
 * Flowdometer Uninstall tab BEFORE uninstalling the managed package.
 *
 * Why this exists: at runtime Flowdometer creates UNMANAGED (non-namespaced)
 * lookup fields on the subscriber's objects that reference the managed Flow__c
 * object. Those fields, plus the runtime-created permission-set assignments,
 * block a clean managed-package uninstall ("This custom object is referenced by
 * a relationship field." / "This permission set is assigned to one or more
 * users.").
 *
 * prepareForUninstall() automates everything that CAN be automated:
 *   1. Deletes the dynamic forward lookup fields via the Metadata API
 *      (SOAP deleteMetadata) using a Visualforce-page API session. The Tooling
 *      API cannot delete CustomField metadata at all, so the Metadata API is the
 *      only option. This operates on the package's own CustomField/PermissionSet
 *      metadata only — it does not create or modify any External Client App.
 *   2. Deactivates all Flowdometer flows (async, via FlowDeactivator).
 *   3. Removes the permission-set / permission-set-group assignments that block
 *      removal of the managed Flowdometer_User permission set (DML).
 *   4. Best-effort removal of the runtime-created unmanaged Permission Set Group
 *      and Permission Set (async, after the assignment DML commits).
 *
 * IMPORTANT subscriber step (surfaced by the LWC): Metadata API deletions in a
 * production org always go to the recycle bin (the purgeOnDelete hard-delete
 * option is not permitted in production), so the deleted lookup fields land in
 * each object's "Deleted Fields" list. The admin must ERASE them
 * (Setup > Object Manager > [object] > Fields & Relationships > Deleted Fields
 * > Erase) before the package will uninstall cleanly.
 *
 * Security: gated on the Customize Application permission. Only unmanaged
 * (non-namespaced) fields that reference Flow__c are targeted, discovered by
 * describe. No user-supplied input is accepted.
 */
@RestResource(urlMapping='/flowdometer/deactivateFlows/*')
global with sharing class FlowdometerUninstallHelper {

    private static final String SOAP_NS = 'http://soap.sforce.com/2006/04/metadata';
    private static final String UNMANAGED_PSG = 'Flowdometer_Access';
    private static final String UNMANAGED_PS  = 'Flowdometer_Dynamic_FLS';

    // Flow API names (DeveloperName, unprefixed) deactivated before uninstall.
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

    global class UninstallResponse {
        @AuraEnabled global Boolean success;
        @AuraEnabled global String  message;
        @AuraEnabled global Integer deactivatedCount;
        @AuraEnabled global Integer fieldsRemoved;
        @AuraEnabled global Integer assignmentsRemoved;
        @AuraEnabled global Boolean manualEraseRequired;

        global UninstallResponse() {
            this.success             = false;
            this.message             = '';
            this.deactivatedCount    = 0;
            this.fieldsRemoved       = 0;
            this.assignmentsRemoved  = 0;
            this.manualEraseRequired = false;
        }
    }

    // ── Comprehensive pre-uninstall action (LWC) ────────────────────

    @AuraEnabled
    public static UninstallResponse prepareForUninstall(String apiSessionId) {
        if (!hasCustomizeApplication()) {
            throw buildAuraException(
                'Only administrators with the Customize Application permission can prepare Flowdometer for uninstall.');
        }

        UninstallResponse resp = new UninstallResponse();
        String sessionId = String.isNotBlank(apiSessionId) ? apiSessionId : getApiSession();

        // 1. Delete dynamic forward lookup fields (CALLOUT — must precede DML).
        List<String> forwardFields = discoverForwardLookupFields();
        if (!forwardFields.isEmpty()) {
            resp.fieldsRemoved = deleteMetadataItems('CustomField', forwardFields, sessionId);
            resp.manualEraseRequired = resp.fieldsRemoved > 0;
        }

        // 2. Remove permission-set / PSG assignments (DML — after callout).
        resp.assignmentsRemoved = removeAssignments();

        // 3. Deactivate flows (async, Tooling PATCH).
        System.enqueueJob(new FlowDeactivator(FLOWDOMETER_FLOWS));
        resp.deactivatedCount = FLOWDOMETER_FLOWS.size();

        // 4. Best-effort cleanup of the unmanaged PSG + PS, after the assignment
        //    DML commits (a PSG cannot be deleted while still assigned).
        if (!Test.isRunningTest()) {
            System.enqueueJob(new PsgCleanupJob(sessionId));
        }

        resp.success = true;
        resp.message = buildSummary(resp);

        System.debug(LoggingLevel.INFO,
            'Flowdometer uninstall prep by ' + UserInfo.getUserId() + ' at ' + System.now()
            + ' (fields=' + resp.fieldsRemoved + ', assignments=' + resp.assignmentsRemoved + ')');

        return resp;
    }

    // ── Legacy flow-only deactivation (REST + backward compatibility) ─

    // POST (not GET): deactivating flows is a state-changing operation, so it
    // must not be reachable via an idempotent/CSRF-prone GET. Authorization is
    // enforced (Customize Application) before any state change.
    @HttpPost
    global static UninstallResponse deactivateFlowsREST() {
        UninstallResponse resp = new UninstallResponse();
        if (!hasCustomizeApplication()) {
            resp.success = false;
            resp.message = 'Only administrators with the Customize Application permission '
                + 'can deactivate Flowdometer flows.';
            return resp;
        }
        try {
            resp.deactivatedCount = deactivateFlows();
            resp.success = true;
            resp.message = 'Deactivated ' + resp.deactivatedCount + ' flows. Run "Prepare for '
                + 'Uninstall" in the Flowdometer app to also remove dynamic lookup fields and '
                + 'permission assignments before uninstalling.';
        } catch (Exception e) {
            resp.success = false;
            resp.message = 'Error deactivating flows: ' + e.getMessage();
        }
        return resp;
    }

    @AuraEnabled
    public static Integer deactivateFlows() {
        if (!hasCustomizeApplication()) {
            throw buildAuraException(
                'Only administrators with the Customize Application permission can deactivate Flowdometer flows.');
        }
        System.enqueueJob(new FlowDeactivator(FLOWDOMETER_FLOWS));
        return FLOWDOMETER_FLOWS.size();
    }

    /**
     * Read-only authorization check for the Uninstall LWC. Lets the UI disable
     * the action and explain the requirement before the user clicks, mirroring
     * the server-side Customize Application gate on prepareForUninstall().
     * Cacheable + side-effect-free, so it is safe to call from connectedCallback.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean canPrepareForUninstall() {
        return hasCustomizeApplication();
    }

    // ── Discovery ───────────────────────────────────────────────────

    /**
     * Returns Object.Field__c member names for the unmanaged (runtime-created)
     * lookup fields on other objects that reference the managed Flow__c object.
     * Packaged (namespaced) fields are excluded. Discovery is describe-based
     * (the Tooling CustomField object has no queryable ReferenceTo column).
     */
    @TestVisible
    private static List<String> discoverForwardLookupFields() {
        List<String> members = new List<String>();
        String ns = resolveNamespace();
        String nsPrefix = String.isBlank(ns) ? null : (ns + '__');
        Schema.DescribeSObjectResult flowDescribe = Flow__c.SObjectType.getDescribe();

        for (Schema.ChildRelationship cr : flowDescribe.getChildRelationships()) {
            Schema.SObjectField fld = cr.getField();
            if (fld == null) { continue; }
            Schema.DescribeFieldResult dfr = fld.getDescribe();
            if (!dfr.isCustom()) { continue; }
            String fieldName = dfr.getName();
            if (nsPrefix != null && fieldName.startsWith(nsPrefix)) { continue; } // packaged
            members.add(cr.getChildSObject().getDescribe().getName() + '.' + fieldName);
        }
        return members;
    }

    // ── Metadata API (SOAP deleteMetadata) ──────────────────────────

    /**
     * Deletes metadata components of a single type via the Metadata API
     * (max 10 fullNames per CRUD call). Returns the number reported deleted.
     */
    @TestVisible
    private static Integer deleteMetadataItems(String type_x, List<String> fullNames, String sessionId) {
        Integer removed = 0;
        String endpoint = URL.getOrgDomainUrl().toExternalForm() + '/services/Soap/m/65.0';
        for (Integer i = 0; i < fullNames.size(); i += 10) {
            List<String> chunk = new List<String>();
            for (Integer j = i; j < Math.min(i + 10, fullNames.size()); j++) {
                chunk.add(fullNames[j]);
            }
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml; charset=UTF-8');
            req.setHeader('SOAPAction', 'deleteMetadata');
            req.setBody(buildDeleteMetadataEnvelope(sessionId, type_x, chunk));
            req.setTimeout(60000);

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() == 200) {
                removed += countTrue(res.getBody());
            } else {
                System.debug(LoggingLevel.ERROR,
                    'deleteMetadata(' + type_x + ') HTTP ' + res.getStatusCode() + ': ' + res.getBody());
            }
        }
        return removed;
    }

    @TestVisible
    private static String buildDeleteMetadataEnvelope(String sessionId, String type_x, List<String> fullNames) {
        String members = '';
        for (String fn : fullNames) {
            members += '<met:fullNames>' + escapeXml(fn) + '</met:fullNames>';
        }
        return '<?xml version="1.0" encoding="UTF-8"?>'
            + '<soapenv:Envelope'
            + ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'
            + ' xmlns:met="' + SOAP_NS + '">'
            + '<soapenv:Header><met:SessionHeader><met:sessionId>'
            + escapeXml(sessionId)
            + '</met:sessionId></met:SessionHeader></soapenv:Header>'
            + '<soapenv:Body><met:deleteMetadata>'
            + '<met:type>' + escapeXml(type_x) + '</met:type>'
            + members
            + '</met:deleteMetadata></soapenv:Body></soapenv:Envelope>';
    }

    private static Integer countTrue(String body) {
        if (String.isBlank(body)) { return 0; }
        Integer count = 0;
        Integer idx = body.indexOf('<success>true</success>');
        while (idx >= 0) {
            count++;
            idx = body.indexOf('<success>true</success>', idx + 1);
        }
        return count;
    }

    // ── Permission cleanup ──────────────────────────────────────────

    private static Integer removeAssignments() {
        List<PermissionSetAssignment> toDelete = [
            SELECT Id FROM PermissionSetAssignment
            WHERE PermissionSet.Name = 'Flowdometer_User'
               OR PermissionSetGroup.DeveloperName = :UNMANAGED_PSG
        ];
        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
        return toDelete.size();
    }

    /**
     * Deletes the unmanaged Permission Set Group and Permission Set created at
     * runtime, in a separate transaction so the assignment DML has committed
     * (a PSG cannot be deleted while assigned). Best-effort: failures leave
     * empty unmanaged shells that do not block uninstall.
     */
    public class PsgCleanupJob implements Queueable, Database.AllowsCallouts {
        private String sessionId;
        public PsgCleanupJob(String sessionId) { this.sessionId = sessionId; }
        public void execute(QueueableContext qc) {
            try {
                deleteMetadataItems('PermissionSetGroup', new List<String>{ UNMANAGED_PSG }, sessionId);
                deleteMetadataItems('PermissionSet', new List<String>{ UNMANAGED_PS }, sessionId);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'PsgCleanupJob: ' + e.getMessage());
            }
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────

    private static String buildSummary(UninstallResponse r) {
        String msg = 'Flowdometer is being prepared for uninstall: '
            + r.deactivatedCount + ' flow(s) deactivating, '
            + r.fieldsRemoved + ' dynamic lookup field(s) deleted, '
            + r.assignmentsRemoved + ' permission assignment(s) removed.';
        if (r.manualEraseRequired) {
            msg += ' IMPORTANT: deleted lookup fields are placed in each object\'s "Deleted Fields" '
                + 'list. You must Erase them (Setup > Object Manager > [object] > Fields & '
                + 'Relationships > Deleted Fields > Erase) before the package will uninstall cleanly.';
        }
        return msg;
    }

    @TestVisible
    private static Boolean hasCustomizeApplication() {
        return [
            SELECT COUNT() FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
            AND PermissionSet.PermissionsCustomizeApplication = true
        ] > 0;
    }

    private static String resolveNamespace() {
        String className = FlowdometerUninstallHelper.class.getName();
        return className.contains('.') ? className.substringBefore('.') : '';
    }

    private static String getApiSession() {
        try {
            PageReference vfPage = Page.FlowdometerSession;
            Blob content = vfPage.getContent();
            Map<String, Object> parsed =
                (Map<String, Object>) JSON.deserializeUntyped(content.toString().trim());
            String sid = (String) parsed.get('sid');
            if (String.isNotBlank(sid)) { return sid; }
        } catch (Exception e) {
            // fall through to Lightning session
        }
        return UserInfo.getSessionId();
    }

    private static AuraHandledException buildAuraException(String msg) {
        AuraHandledException ex = new AuraHandledException(msg);
        ex.setMessage(msg);
        return ex;
    }

    private static String escapeXml(String input) {
        if (String.isBlank(input)) { return ''; }
        return input.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
                    .replace('"', '&quot;').replace('\'', '&apos;');
    }

    public class FlowDeactivationException extends Exception {}
}
