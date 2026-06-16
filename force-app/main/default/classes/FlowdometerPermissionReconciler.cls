/**
 * Setup-Gate Reconciler (Build Plan item A.0).
 *
 * Creates and continuously reconciles the permission infrastructure that backs
 * Flowdometer's dynamic field-level security:
 *
 *   - An UNMANAGED permission set (Flowdometer_Dynamic_FLS) that holds FLS for
 *     every dynamically created lookup field, in BOTH directions: the field on
 *     the subscriber object AND the dynamically created field on the managed
 *     Flow__c object. A managed (packaged) permission set cannot receive
 *     FieldPermissions DML in a subscriber org (CANNOT_MODIFY_MANAGED_OBJECT),
 *     so dynamic FLS must live on an unmanaged PS.
 *   - A Permission Set Group (Flowdometer_Access) that bundles the managed
 *     packaged PS (static, upgrade-propagated FLS) with the unmanaged PS
 *     (dynamic FLS). The PSG is the single unit end users are assigned.
 *
 * Invoked from the post-auth setup gate on every entry, so deleted or
 * admin-edited infrastructure self-heals. A post-install InstallHandler is
 * unsuitable: it runs only at install/upgrade, before auth exists.
 *
 * Resolution strategy: the unmanaged PS and PSG are resolved by their fixed
 * developer names. No NamespacePrefix filter is applied, because a
 * runtime-created component carries the org's namespace in a namespaced org
 * (e.g. the package build org) but null in a subscriber org - resolving by
 * name alone works in both. No packaged permission set ships with these names,
 * so the lookup is unambiguous. This avoids persisting IDs in a custom setting:
 * a protected custom setting cannot be deployed to a non-developer packaging
 * org, and writing one would also collide with the surrounding setup-object DML
 * (MIXED_DML_OPERATION). Name-based resolution gives the same idempotency/
 * self-heal behavior for package-owned components.
 *
 * Sharing: `with sharing` per project security policy. Sharing keywords govern
 * row-level sharing only - NOT FLS. The setup-object DML below is gated by the
 * running user's "Manage Profiles and Permission Sets" permission, not by
 * sharing or FLS. A non-admin caller fails the DML and is told to ask an admin.
 */
public with sharing class FlowdometerPermissionReconciler {

    @TestVisible private static final String UNMANAGED_PS_NAME = 'Flowdometer_Dynamic_FLS';
    @TestVisible private static final String UNMANAGED_PS_LABEL = 'Flowdometer Dynamic FLS';
    @TestVisible private static final String PSG_DEVNAME = 'Flowdometer_Access';
    @TestVisible private static final String PSG_LABEL = 'Flowdometer Access';
    @TestVisible private static final String MANAGED_PS_NAME = 'Flowdometer_User';

    // PSG assignment retry knobs. A freshly created/re-componentized PSG is
    // 'Updating' (async recalculation) and rejects assignments; on a first
    // setup-gate entry the assignment therefore defers - fatal for an admin
    // who creates one listener and never revisits the screen (confirmed
    // 2026-06-10, org flowdometer-qa-28). PSG recalculation can take a few
    // minutes, so allow more attempts than the FLS-grant retry.
    @TestVisible private static final Integer PSG_ASSIGN_MAX_ATTEMPTS = 5;
    private static final Integer PSG_ASSIGN_RETRY_DELAY_MINUTES = 1;
    // Test seam: enqueueJob is skipped in tests, this records the decision.
    @TestVisible private static Boolean psgAssignmentRetryScheduled = false;

    public class ReconcileResult {
        @AuraEnabled public Boolean success = false;
        @AuraEnabled public Boolean adminActionRequired = false;
        @AuraEnabled public String message = '';
    }

    /**
     * Entry point called by the setup-gate LWC on every load. Idempotent:
     * each piece is verified/created/repaired independently.
     */
    @AuraEnabled
    public static ReconcileResult reconcile() {
        ReconcileResult result = new ReconcileResult();
        try {
            Id unmanagedPsId = ensureUnmanagedPermissionSet();
            Id psgId = ensurePermissionSetGroup();
            ensureComponents(psgId, unmanagedPsId);
            // Assign BEFORE reconciling FieldPermissions: inserting
            // FieldPermissions on a PSG component flips the PSG to 'Updating'
            // (async recalculation), which blocks PSG assignment in the same
            // pass. Assigning first lets the assignment land whenever the PSG
            // is already 'Updated'. On a first entry (component inserts above
            // also trigger recalculation) the assignment defers - and a
            // single-visit admin would never return to heal it - so an
            // incomplete pass schedules a delayed unattended retry.
            Boolean allAdminsAssigned = assignGroupToAdmins(psgId);
            if (!allAdminsAssigned) {
                scheduleAssignmentRetry(psgId, 1);
            }
            reconcileFieldPermissions(unmanagedPsId);

            result.success = true;
            result.message = 'Flowdometer permissions are configured.';
        } catch (DmlException de) {
            result.success = false;
            result.adminActionRequired = true;
            result.message =
                'Flowdometer could not finish permission setup. Ask a Salesforce ' +
                'administrator with the "Manage Profiles and Permission Sets" ' +
                'permission to open this setup page once.';
            System.debug(LoggingLevel.ERROR,
                'Reconcile DML failure: ' + de.getMessage() + '\n' + de.getStackTraceString());
        } catch (Exception e) {
            result.success = false;
            result.message = 'Flowdometer setup encountered an unexpected error.';
            System.debug(LoggingLevel.ERROR,
                'Reconcile failure: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
        return result;
    }

    // ── Unmanaged permission set ───────────────────────────────────────

    @TestVisible
    private static Id ensureUnmanagedPermissionSet() {
        // Resolve by name only. The runtime-created PS carries the org namespace
        // in a namespaced build org but null in a subscriber - name alone works
        // in both, and no packaged PS uses this name.
        List<PermissionSet> byName = [
            SELECT Id FROM PermissionSet
            WHERE Name = :UNMANAGED_PS_NAME
            LIMIT 1
        ];
        if (!byName.isEmpty()) {
            return byName[0].Id;
        }
        PermissionSet ps = new PermissionSet(Name = UNMANAGED_PS_NAME, Label = UNMANAGED_PS_LABEL);
        insert ps;
        return ps.Id;
    }

    // ── Permission set group ───────────────────────────────────────────

    @TestVisible
    private static Id ensurePermissionSetGroup() {
        List<PermissionSetGroup> byName = [
            SELECT Id FROM PermissionSetGroup
            WHERE DeveloperName = :PSG_DEVNAME
            LIMIT 1
        ];
        if (!byName.isEmpty()) {
            return byName[0].Id;
        }
        PermissionSetGroup psg = new PermissionSetGroup(
            DeveloperName = PSG_DEVNAME, MasterLabel = PSG_LABEL
        );
        insert psg;
        return psg.Id;
    }

    // ── PSG components (managed PS + unmanaged PS) ──────────────────────

    @TestVisible
    private static void ensureComponents(Id psgId, Id unmanagedPsId) {
        Id managedPsId = resolveManagedPsId();

        Set<Id> existing = new Set<Id>();
        for (PermissionSetGroupComponent comp : [
            SELECT PermissionSetId FROM PermissionSetGroupComponent
            WHERE PermissionSetGroupId = :psgId
        ]) {
            existing.add(comp.PermissionSetId);
        }

        List<PermissionSetGroupComponent> toAdd = new List<PermissionSetGroupComponent>();
        if (unmanagedPsId != null && !existing.contains(unmanagedPsId)) {
            toAdd.add(new PermissionSetGroupComponent(
                PermissionSetGroupId = psgId, PermissionSetId = unmanagedPsId
            ));
        }
        if (managedPsId != null && !existing.contains(managedPsId)) {
            toAdd.add(new PermissionSetGroupComponent(
                PermissionSetGroupId = psgId, PermissionSetId = managedPsId
            ));
        }
        if (!toAdd.isEmpty()) {
            insert toAdd;
        }
    }

    private static Id resolveManagedPsId() {
        String ns = resolveNamespace();
        List<PermissionSet> psList = [
            SELECT Id, NamespacePrefix FROM PermissionSet WHERE Name = :MANAGED_PS_NAME
        ];
        for (PermissionSet ps : psList) {
            if (String.isBlank(ns) || ps.NamespacePrefix == ns) {
                return ps.Id;
            }
        }
        return psList.isEmpty() ? null : psList[0].Id;
    }

    // ── FieldPermissions reconciliation (both lookup directions) ────────

    /**
     * Reconcile FieldPermissions on the unmanaged PS against the dynamic fields
     * implied by the live Listener__c records. Closes the drift case where an
     * admin removes a FieldPermissions entry from the (editable) unmanaged PS.
     * Best-effort per row: a field that does not exist yet simply fails its
     * insert and is reconciled on a later entry once the field exists.
     */
    @TestVisible
    private static void reconcileFieldPermissions(Id unmanagedPsId) {
        if (unmanagedPsId == null || !Schema.sObjectType.Listener__c.isAccessible()) {
            return;
        }
        List<Listener__c> listeners = [
            SELECT Object_Name__c, Field_To_Track__c
            FROM Listener__c
            WHERE Object_Name__c != NULL AND Field_To_Track__c != NULL
        ];
        if (listeners.isEmpty()) {
            return;
        }

        String flowObjectApi = Flow__c.SObjectType.getDescribe().getName();

        // Desired field-full-name -> owning SObjectType.
        Map<String, String> desiredObjectByField = new Map<String, String>();
        for (Listener__c listener : listeners) {
            Schema.SObjectType trackedType = Schema.getGlobalDescribe().get(listener.Object_Name__c);
            if (trackedType == null) {
                continue;
            }
            Schema.DescribeSObjectResult trackedDescribe = trackedType.getDescribe();
            String trackedObjectLabel = trackedDescribe.getLabel();
            Schema.SObjectField fld = trackedDescribe.fields.getMap().get(listener.Field_To_Track__c.toLowerCase());
            String trackedFieldLabel = (fld != null) ? fld.getDescribe().getLabel() : listener.Field_To_Track__c;

            // Forward field on the tracked object; reverse field on Flow__c.
            String forwardField = MetaDataUtilityCls.convertLabeltoAPIName(trackedFieldLabel + ' Flow');
            String reverseField = MetaDataUtilityCls.convertLabeltoAPIName(trackedObjectLabel);

            desiredObjectByField.put(listener.Object_Name__c + '.' + forwardField, listener.Object_Name__c);
            desiredObjectByField.put(flowObjectApi + '.' + reverseField, flowObjectApi);
        }
        if (desiredObjectByField.isEmpty()) {
            return;
        }

        Set<String> alreadyGranted = new Set<String>();
        for (FieldPermissions fp : [
            SELECT Field FROM FieldPermissions
            WHERE ParentId = :unmanagedPsId AND Field IN :desiredObjectByField.keySet()
        ]) {
            alreadyGranted.add(fp.Field);
        }

        List<FieldPermissions> toInsert = new List<FieldPermissions>();
        for (String fieldFullName : desiredObjectByField.keySet()) {
            if (alreadyGranted.contains(fieldFullName)) {
                continue;
            }
            toInsert.add(new FieldPermissions(
                ParentId = unmanagedPsId,
                SobjectType = desiredObjectByField.get(fieldFullName),
                Field = fieldFullName,
                PermissionsRead = true,
                PermissionsEdit = true
            ));
        }
        if (!toInsert.isEmpty()) {
            // Best-effort: rows for fields that have not propagated yet fail
            // individually without aborting the rest.
            Database.insert(toInsert, false);
        }
    }

    // ── PSG assignment to administrators ───────────────────────────────

    /**
     * Assign the PSG to all active administrators. Capability-based detection
     * (PermissionsModifyAllData) avoids hard-coding a profile name, which varies
     * by locale and fails Checkmarx. Best-effort: assignment of a PSG that is
     * still recalculating fails per-row; the caller schedules a delayed retry
     * (and any later gate entry also re-attempts).
     *
     * @return true when every active admin holds an assignment after this pass.
     */
    @TestVisible
    private static Boolean assignGroupToAdmins(Id psgId) {
        if (psgId == null) {
            return true;
        }
        Set<Id> adminProfileIds = new Map<Id, Profile>([
            SELECT Id FROM Profile WHERE PermissionsModifyAllData = true
        ]).keySet();
        if (adminProfileIds.isEmpty()) {
            return true;
        }

        Set<Id> alreadyAssigned = new Set<Id>();
        for (PermissionSetAssignment psa : [
            SELECT AssigneeId FROM PermissionSetAssignment
            WHERE PermissionSetGroupId = :psgId
        ]) {
            alreadyAssigned.add(psa.AssigneeId);
        }

        List<PermissionSetAssignment> toAssign = new List<PermissionSetAssignment>();
        for (User u : [
            SELECT Id FROM User
            WHERE IsActive = true AND ProfileId IN :adminProfileIds
        ]) {
            if (!alreadyAssigned.contains(u.Id)) {
                toAssign.add(new PermissionSetAssignment(
                    PermissionSetGroupId = psgId, AssigneeId = u.Id
                ));
            }
        }
        if (toAssign.isEmpty()) {
            return true;
        }
        Boolean allSucceeded = true;
        for (Database.SaveResult sr : Database.insert(toAssign, false)) {
            if (!sr.isSuccess()) {
                allSucceeded = false;
                System.debug(LoggingLevel.WARN,
                    'PSG assignment deferred (PSG likely recalculating): ' + sr.getErrors());
            }
        }
        return allSucceeded;
    }

    /**
     * Schedule a delayed unattended re-attempt of the PSG assignment.
     * Idempotent in effect: each retry pass only inserts missing assignments,
     * and the chain ends as soon as every admin is assigned or attempts are
     * exhausted (any later setup-gate entry still re-attempts as before).
     */
    private static void scheduleAssignmentRetry(Id psgId, Integer attempt) {
        if (attempt > PSG_ASSIGN_MAX_ATTEMPTS) {
            return;
        }
        psgAssignmentRetryScheduled = true;
        if (!Test.isRunningTest()) {
            System.enqueueJob(
                new PsgAssignmentRetryJob(psgId, attempt),
                PSG_ASSIGN_RETRY_DELAY_MINUTES
            );
        }
    }

    /**
     * Delayed retry worker for the PSG assignment (same pattern as the
     * FLSGrantJob retry). Runs as the user who entered the setup gate, who
     * already held "Manage Profiles and Permission Sets" for the original
     * reconcile pass.
     */
    public with sharing class PsgAssignmentRetryJob implements Queueable {
        Id psgId;
        Integer attempt;
        public PsgAssignmentRetryJob(Id groupId, Integer attemptNumber) {
            psgId = groupId;
            attempt = attemptNumber;
        }
        public void execute(QueueableContext qc) {
            Boolean allAssigned = assignGroupToAdmins(psgId);
            System.debug(LoggingLevel.INFO,
                'PsgAssignmentRetryJob: attempt ' + attempt + ' of ' + PSG_ASSIGN_MAX_ATTEMPTS +
                ', allAssigned=' + allAssigned);
            if (!allAssigned) {
                scheduleAssignmentRetry(psgId, attempt + 1);
            }
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────

    private static String resolveNamespace() {
        String className = FlowdometerPermissionReconciler.class.getName();
        return className.contains('.') ? className.substringBefore('.') : '';
    }
}
