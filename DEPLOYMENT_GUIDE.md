# Deployment Guide - Flowdometer Changes

## Quick Deploy Command

Deploy all changes to your Salesforce org:

```powershell
# Deploy all modified files
sfdx force:source:deploy `
  -p "force-app/main/default/classes,force-app/main/default/lwc" `
  -w 30
```

Or use the deployment script:

```powershell
.\deploy-changes.ps1
```

## Files Being Deployed

### Apex Classes (Modified)
1. ✅ `MetaDataUtilityCls.cls` - Bug fixes and Tooling API support
2. ✅ `PostInstallScript.cls` - Complete InstallHandler implementation
3. ✅ `controllers/ListenerFlowController.cls` - Critical bug fixes and FLS checks
4. ✅ `controllers/ListenerMasterConfigurationController.cls` - FLS checks and error handling
5. ✅ `controllers/tests/ListenerMasterConfigControllerTest.cls` - Test coverage improvements

### Lightning Web Components (Modified/New)
1. ✅ `flowdometerUninstallHelper` - UI improvements
2. ✅ `viewAllDashboards` - **NEW** component

## Pre-Deployment Checklist

- [x] Code review completed (see `CODE_REVIEW_2025-11-21.md`)
- [x] All FLS checks added
- [x] NullPointerException issues fixed
- [x] SOQL injection prevention verified
- [x] No breaking changes detected

## Deployment Steps

### Option 1: Deploy via Script (Recommended)

```powershell
.\deploy-changes.ps1
```

### Option 2: Deploy via CLI

```powershell
# 1. Check org connection
sfdx force:org:display

# 2. Deploy all changes
sfdx force:source:deploy `
  -p "force-app/main/default/classes,force-app/main/default/lwc" `
  -w 30

# 3. (Optional) Run tests
sfdx force:apex:test:run -l RunLocalTests -w 60 -r human
```

### Option 3: Deploy Specific Files

If you want to deploy files individually:

```powershell
# Deploy classes only
sfdx force:source:deploy -p "force-app/main/default/classes" -w 30

# Deploy LWC only
sfdx force:source:deploy -p "force-app/main/default/lwc" -w 30
```

## Post-Deployment Verification

### 1. Verify PostInstallScript
- Check debug logs after deployment
- Verify permission set `Flowdometer__Flowdometer_User` is assigned to active users
- If not assigned automatically, manually assign to users

### 2. Test Type Field Functionality
- Create a new Listener with a Type field configured
- Verify that `varType` in flows contains the actual field value (e.g., "New Business") not the field API name

### 3. Test Error Handling
- Verify error messages display correctly in Listener records
- Test with deleted parent records (should show "[Record Deleted]")
- Verify FLS checks work (errors should be handled gracefully)

### 4. Test New Components
- Navigate to `viewAllDashboards` component
- Test `flowdometerUninstallHelper` "Open Flows" button

### 5. Run Tests
```powershell
sfdx force:apex:test:run -l RunLocalTests -w 60 -r human
```

## Troubleshooting

### Deployment Fails with "Permission Denied"
- Check that you have the necessary permissions in your org
- Verify you're connected to the correct org: `sfdx force:org:display`

### PostInstallScript Doesn't Run
- PostInstallScript only runs on package installation/upgrade
- For existing installations, manually assign permission sets
- Check debug logs for any errors

### Type Field Still Shows API Name
- Verify the Type__c field is included in the parent query
- Check debug logs for field validation errors
- Ensure the field exists on the tracked object

### Tests Fail
- Some tests may fail if standard objects don't support history tracking (expected)
- Check test results for specific failures
- Review debug logs for detailed error messages

## Rollback Plan

If you need to rollback:

```powershell
# 1. Check out previous commit
git checkout c451f6c -- force-app/main/default/classes force-app/main/default/lwc

# 2. Deploy previous version
sfdx force:source:deploy -p "force-app/main/default/classes,force-app/main/default/lwc" -w 30
```

## Support

If you encounter issues:
1. Check debug logs in Salesforce Setup
2. Review `CODE_REVIEW_2025-11-21.md` for known issues
3. Check `MERGE_GUIDE.md` for context on changes

---

**Ready to Deploy?** Run: `.\deploy-changes.ps1` or use the CLI command above.

