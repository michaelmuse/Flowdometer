# Test Plan: Post-Security Fixes Verification

**Date**: November 23, 2025  
**Purpose**: Verify all Flowdometer features still work correctly after security hardening changes

---

## Critical Path Tests (Must Pass)

### 1. Create New Listener Record
**What Changed**: Added FLS checks before field assignments and `WITH SECURITY_ENFORCED` to queries

**Test Steps**:
1. Navigate to **Setup Listeners** page (or Listener__c tab)
2. Click **New** to create a new Listener
3. Fill in:
   - **Object Name**: `Opportunity` (or any standard object)
   - **Field To Track**: `StageName` (or any tracked field)
   - **Type** (optional): `Type`
4. Click **Save**

**Expected Results**:
- ✅ Listener record is created successfully
- ✅ No error messages appear
- ✅ If history tracking is not enabled, a warning appears in `Error_Message__c` field
- ✅ Lookup field creation job is enqueued (check debug logs)

**What to Check**:
- Verify `Flowdometer__Error_Message__c` field is populated if applicable
- Check that `Last_Execution_On__c` is null initially
- Verify `isActive__c` defaults to true

---

### 2. Background Tracker Check (Future Method)
**What Changed**: Added access checks before querying Listener/Flow records

**Test Steps**:
1. Create a Listener (as in Test #1)
2. Wait 1-2 minutes OR manually trigger the scheduled flow
3. Check the Listener record after the delay

**Expected Results**:
- ✅ `checkTrackersAfterDelay` future method runs without errors
- ✅ If no Flow records are created, `Error_Message__c` contains a warning
- ✅ If Flow records exist, no error message appears
- ✅ History tracking status is checked and logged

**What to Check**:
- Debug logs show "Checking tracker creation for Listener ID: [ID]"
- No "Insufficient access" errors in logs
- Listener record updates correctly

---

### 3. Lookup Field Creation (Queueable)
**What Changed**: Changed `LookupFieldCreator` to `inherited sharing`

**Test Steps**:
1. Create a new Listener for a custom object (e.g., `Custom_Object__c`)
2. Ensure the object doesn't already have the lookup field
3. Wait for the queueable job to execute (or check debug logs)

**Expected Results**:
- ✅ Queueable job executes successfully
- ✅ Lookup field is created on the target object
- ✅ If field already exists, job logs and returns gracefully
- ✅ If creation fails, error message is stored in Listener's `Error_Message__c`

**What to Check**:
- Verify the lookup field appears on the target object
- Check debug logs for "Successfully created lookup field" or error messages
- Verify error handling works if metadata API fails

---

### 4. History Record Processing (Main Flow Functionality)
**What Changed**: Added `WITH SECURITY_ENFORCED` to all dynamic queries and FLS checks before field updates

**Test Steps**:
1. Ensure you have a Listener configured for an object with history tracking enabled
2. Create or update a record that matches the Listener's criteria
3. Wait for the scheduled flow to run (every 3 minutes) OR manually trigger it
4. Check that Flow and Step records are created

**Expected Results**:
- ✅ Flow records are created for tracked objects
- ✅ Step records are created when field values change
- ✅ `Last_Execution_On__c` is updated on the Listener
- ✅ `Last_Check__c` is updated to trigger next scheduled run
- ✅ No "WITH SECURITY_ENFORCED" query errors

**What to Check**:
- Verify Flow__c records exist for the tracked object
- Verify Step__c records exist with correct field values
- Check that `Error_Message__c` is cleared if processing succeeds
- Verify history records are queried correctly

---

### 5. View All Dashboards / Flow List
**What Changed**: Added CRUD/FLS checks and `WITH SECURITY_ENFORCED` to GetFlowsListController

**Test Steps**:
1. Navigate to the **View All Dashboards** Lightning component
2. Click the **Open Dashboards** button
3. OR navigate to a Flow__c record detail page
4. Check the related list for Flow records

**Expected Results**:
- ✅ Component loads without errors
- ✅ Dashboard navigation works
- ✅ Flow list displays correctly
- ✅ No "insufficient access" errors

**What to Check**:
- Verify the LWC component renders
- Check that Flow records are visible if user has access
- Verify no console errors in browser dev tools

---

### 6. Error Message Updates Throughout System
**What Changed**: All error message field assignments now have FLS checks

**Test Scenarios**:

**6a. Error on History Query**:
- Create a Listener with invalid configuration
- Trigger history processing
- Verify `Error_Message__c` is populated with error details

**6b. Error on Retry Limit**:
- Simulate multiple failures (if possible)
- Verify retry count logic works
- Check that max retry error message appears

**6c. Error on Field Update**:
- Test with a user who has limited field access
- Verify error messages are still set when FLS allows it
- Verify updates are skipped gracefully when FLS denies it

**Expected Results**:
- ✅ Error messages are stored when FLS allows
- ✅ No exceptions thrown when FLS denies (graceful degradation)
- ✅ Error messages are readable and helpful

---

## Edge Case Tests

### 7. User with Limited Permissions
**Test Steps**:
1. Create a test user with:
   - Read access to Listener__c
   - No update access to `Error_Message__c` field
   - Limited access to Flow__c and Step__c
2. Log in as this user
3. Try to create a Listener (if they have create access)
4. Check what happens when background jobs run

**Expected Results**:
- ✅ System gracefully handles missing permissions
- ✅ No security exceptions thrown
- ✅ Error messages logged to debug logs
- ✅ User sees appropriate error messages (not technical details)

---

### 8. Large History Object Processing
**What Changed**: Queries now have `WITH SECURITY_ENFORCED` which could affect performance

**Test Steps**:
1. Use a Listener tracking an object with many history records (e.g., Case, Opportunity)
2. Ensure history tracking is enabled
3. Trigger history processing
4. Monitor CPU time and query performance

**Expected Results**:
- ✅ Queries complete successfully
- ✅ No governor limit errors
- ✅ Processing completes within reasonable time
- ✅ Batching works correctly for large datasets

---

### 9. Unprocessed History Records (Backlog)
**What Changed**: FLS check added before updating `Unprocessed_History_Records__c`

**Test Steps**:
1. Create a scenario where more than 20 history records need processing
2. Trigger the flow multiple times
3. Verify backlog is stored and processed correctly

**Expected Results**:
- ✅ Backlog is stored in `Unprocessed_History_Records__c` field
- ✅ Backlog is processed in subsequent runs
- ✅ Field is cleared when all records are processed
- ✅ No FLS errors when updating the field

---

### 10. Enable History Toggle
**What Changed**: Queries respect the `Enable_History__c` toggle with security checks

**Test Steps**:
1. Create a Listener with `Enable_History__c = false`
2. Verify historical queries are skipped
3. Verify new history queries still work
4. Toggle `Enable_History__c = true`
5. Verify historical queries now run

**Expected Results**:
- ✅ Toggle correctly controls historical data queries
- ✅ New history queries always work regardless of toggle
- ✅ `Last_Execution_On__c` is set even when toggle is disabled
- ✅ No errors when toggle state changes

---

## Integration Tests

### 11. Full End-to-End Flow
**Test Steps**:
1. Create a new Listener for `Case` object tracking `Status` field
2. Ensure history tracking is enabled for Case.Status
3. Create a new Case record
4. Update the Case Status multiple times
5. Wait for scheduled flow to process
6. Check Flow and Step records are created
7. View dashboards to see the data

**Expected Results**:
- ✅ Complete flow works end-to-end
- ✅ All records created correctly
- ✅ All timestamps accurate
- ✅ Dashboards display data correctly

---

## Regression Tests

### 12. Existing Listeners Continue Working
**Test Steps**:
1. Identify existing active Listeners in your org
2. Verify they continue processing after deployment
3. Check that no errors appear in debug logs
4. Verify Flow/Step records continue to be created

**Expected Results**:
- ✅ Existing Listeners unaffected
- ✅ No breaking changes
- ✅ Backward compatibility maintained

---

## Performance Tests

### 13. Query Performance
**What Changed**: Added `WITH SECURITY_ENFORCED` to all queries

**Test Steps**:
1. Monitor query performance in debug logs
2. Check for any significant slowdowns
3. Verify query plans are efficient

**Expected Results**:
- ✅ No significant performance degradation
- ✅ Queries complete within acceptable timeframes
- ✅ No new governor limit issues

---

## Test Checklist Summary

- [ ] **Test 1**: Create New Listener Record
- [ ] **Test 2**: Background Tracker Check
- [ ] **Test 3**: Lookup Field Creation
- [ ] **Test 4**: History Record Processing
- [ ] **Test 5**: View All Dashboards / Flow List
- [ ] **Test 6**: Error Message Updates (all scenarios)
- [ ] **Test 7**: User with Limited Permissions
- [ ] **Test 8**: Large History Object Processing
- [ ] **Test 9**: Unprocessed History Records
- [ ] **Test 10**: Enable History Toggle
- [ ] **Test 11**: Full End-to-End Flow
- [ ] **Test 12**: Existing Listeners Continue Working
- [ ] **Test 13**: Query Performance

---

## What to Monitor

### Debug Logs
Watch for:
- ✅ "WITH SECURITY_ENFORCED" in queries (expected)
- ❌ "Insufficient access" errors (should not appear)
- ❌ "FLS check failed" messages (should be handled gracefully)
- ✅ Successful field updates and queries

### Error Messages
Check:
- ✅ Error messages are user-friendly
- ✅ Technical details only in debug logs
- ✅ No security exception stack traces visible to users

### Data Integrity
Verify:
- ✅ All records created correctly
- ✅ Field values are accurate
- ✅ Timestamps are correct
- ✅ Relationships are maintained

---

## Rollback Plan

If any critical issues are found:
1. The previous version is still in git history
2. Revert the specific class causing issues
3. Redeploy only the working version
4. Document the issue for follow-up

---

**Note**: All tests should be run in a sandbox environment before production deployment.

