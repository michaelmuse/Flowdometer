# Backup Differences Summary

This document summarizes the differences between the stashed backup and the current clean version.

## Summary Statistics

- **Total files in stash**: 991 files (mostly .history VSCode files - can be ignored)
- **Files with differences**: 78 files (excluding .history files)
  - **Meaningful differences** (line count changed): 74 files
  - **Formatting-only differences** (same line count, different content): 4 files
- **New files in stash**: 14 files (legacy duplicates and data files)
- **Identical files**: 0 files found (likely due to minor formatting differences like trailing newlines, whitespace, or line endings)

**Note**: The 0 identical files count is likely because even files with identical logic may have minor formatting differences (trailing newlines, whitespace, line endings). Most differences are only 1 line, suggesting formatting-only changes.

## Important Files with Differences

### Configuration Files
1. **`.gitignore`** - Current version is more comprehensive (90 lines vs 83 lines in stash) - **7 lines added**
2. **`.forceignore`** - Current version has fewer entries (18 lines vs 21 lines in stash) - **3 lines removed**
3. **`.prettierignore`** - Same line count (13 lines) but content differs - **formatting only**
4. **`.prettierrc`** - Same line count (21 lines) but content differs - **formatting only**
5. **`.vscode/settings.json`** - Current version has 9 lines vs 10 lines in stash - **1 line removed**
6. **`.pmdCache`** - Same line count (3 lines) but content differs - **formatting only**

### Apex Classes
1. **`force-app/main/default/classes/CalculateBusinessHoursDiff.cls`** - 1 line difference (87 lines in stash vs 88 in current)
2. **`force-app/main/default/classes/MetaDataUtilityCls.cls`** - **MAJOR DIFFERENCE**: 818 lines in stash vs 715 lines in current (**+103 lines in stash**)
3. **`force-app/main/default/classes/PostInstallScript.cls`** - **MAJOR DIFFERENCE**: 57 lines in stash vs 3 lines in current (**+54 lines in stash**)
4. **`force-app/main/default/classes/controllers/ListenerFlowController.cls`** - Does NOT exist in stash (file was created after reorganization)
5. **`force-app/main/default/classes/ListenerFlowController.cls`** - NEW in stash (legacy duplicate - moved to controllers/ folder)
6. **`force-app/main/default/classes/GetFlowsListController.cls`** - NEW in stash (legacy duplicate - moved to controllers/ folder)
7. **`force-app/main/default/classes/ListenerUpdateFlowController.cls`** - NEW in stash (legacy duplicate - moved to controllers/ folder)

### Test Classes (NEW in stash - legacy duplicates)
- `ListenerFlowControllerTest.cls`
- `ListenerUpdateFlowControllerTest.cls`
- `MetaDataUtilityClsTest.cls`
- `MetadataServiceTest.cls`
- `TestDataFactoryTest.cls`
- `CalculateBusinessHoursDiffTest.cls`

### Flows
All flow files show **1 line difference** (likely trailing newline or formatting):
- `Asana_Task_changes_create_Flows_and_Steps.flow-meta.xml` (283 vs 284 lines)
- `Asana_Task_created_in_Asana.flow-meta.xml` (203 vs 204 lines)
- `Assign_New_Goals_to_Matching_Flows_with_No_Goal.flow-meta.xml` (323 vs 324 lines)
- `Case_Status_changes_create_Flows_and_Steps.flow-meta.xml` (370 vs 371 lines)
- `Flowdometer_Autocalculate_Business_Hours.flow-meta.xml` (114 vs 115 lines)
- `Flowdometer_Update_Tasks_with_Current_Step.flow-meta.xml` (216 vs 217 lines)
- `Lead_Status_changes_create_Flows_and_Steps.flow-meta.xml` (381 vs 382 lines)
- `Listener_Batch_Flow.flow-meta.xml` (179 vs 180 lines)
- `Listener_Configuration_Main_Flow.flow-meta.xml` (795 vs 796 lines)
- `Listener_Flow_Sub_Flow.flow-meta.xml` (1263 vs 1264 lines)
- `Opportunity_Stage_changes_create_Flows_and_Steps.flow-meta.xml` (370 vs 371 lines)
- `asana_makes_flows_and_steps.flow-meta.xml` (326 vs 327 lines)
- `Test.flow-meta.xml` - Could not extract from stash
- `testmsp.flow-meta.xml` - Could not extract from stash

### Lightning Web Components
All LWC files show **1 line difference** (likely trailing newline):
- `customErrorMessage/customErrorMessage.html` (38 vs 39 lines)
- `customErrorMessage/customErrorMessage.js` (85 vs 86 lines)
- `flowdometerInstructions/flowdometerInstructions.css` (46 vs 47 lines)
- `flowdometerInstructions/flowdometerInstructions.html` (52 vs 53 lines)
- `flowdometerInstructions/flowdometerInstructions.js` (98 vs 99 lines)
- `listenerMasterConfiguration/listenerMasterConfiguration.html` (118 vs 119 lines)
- `listenerMasterConfiguration/listenerMasterConfiguration.js` (407 vs 408 lines)
- `listenerMasterConfiguration/listenerMasterConfiguration.js-meta.xml` (same line count, formatting only)
- `modal/modal.html` (48 vs 49 lines)
- `modal/modal.js` (48 vs 49 lines)

### Object Metadata
All object metadata files show **1 line difference** (likely trailing newline or formatting):
- **Flow__c object**: `Next_Breach_At__c` (13 vs 14 lines), `Progress_Bar_vs_Goal__c` (17 vs 18 lines)
- **Listener__c object**: Object definition (175 vs 176 lines) and all fields show 1 line difference
- **Step__c object**: All fields show 1 line difference (likely formatting/trailing newline)

## Files to Keep from Backup

Based on the analysis, the following files in the backup contain changes that may need to be preserved:

### Legacy Duplicate Classes (in root classes folder)
These are duplicates that exist in the `controllers/` folder in the current version:
- `force-app/main/default/classes/ListenerFlowController.cls` - [LEGACY DUPLICATE]
- `force-app/main/default/classes/GetFlowsListController.cls` - [LEGACY DUPLICATE]
- `force-app/main/default/classes/ListenerUpdateFlowController.cls` - [LEGACY DUPLICATE]

### Test Classes (legacy duplicates)
- `force-app/main/default/classes/ListenerFlowControllerTest.cls` - [LEGACY DUPLICATE]
- `force-app/main/default/classes/ListenerUpdateFlowControllerTest.cls` - [LEGACY DUPLICATE]
- `force-app/main/default/classes/MetaDataUtilityClsTest.cls` - [LEGACY DUPLICATE]
- `force-app/main/default/classes/MetadataServiceTest.cls` - [LEGACY DUPLICATE]
- `force-app/main/default/classes/TestDataFactoryTest.cls` - [LEGACY DUPLICATE]
- `force-app/main/default/classes/CalculateBusinessHoursDiffTest.cls` - [LEGACY DUPLICATE]

### Other Files
- `Flow_ids.csv` - Data file, may contain important IDs

## Key Findings

### Files Requiring Review (Significant Differences)

1. **`MetaDataUtilityCls.cls`** - **+103 lines in stash** (818 vs 715) - This is a significant difference that needs review
2. **`PostInstallScript.cls`** - **+54 lines in stash** (57 vs 3) - Major difference, stash version is much longer
3. **`.gitignore`** - Current version has 7 more lines (90 vs 83) - Current version is more complete
4. **`.forceignore`** - Stash has 3 more lines (21 vs 18) - May have entries worth keeping

### Files with Minor Differences (Likely Formatting Only)

- **Most flow files**: 1 line difference (likely trailing newline)
- **Most LWC files**: 1 line difference (likely trailing newline)
- **Most object metadata files**: 1 line difference (likely formatting)
- **Configuration files**: `.prettierignore`, `.prettierrc`, `.pmdCache` - Same line count, formatting only

## Recommendation

1. **Ignore `.history/` files** - These are VSCode history files and can be safely discarded (~900+ files)
2. **Review major differences**:
   - `MetaDataUtilityCls.cls` - Check if the 103 extra lines in stash contain important code
   - `PostInstallScript.cls` - The stash version is much longer (57 vs 3 lines) - needs review
3. **Review configuration files**:
   - `.forceignore` - Stash has 3 more lines, check if they're needed
   - `.gitignore` - Current version is more complete, but verify no important entries were lost
4. **Legacy duplicate classes** - These appear to be old versions that have been moved to the `controllers/` folder. They can likely be discarded unless they contain unique code
5. **Minor differences** - Most 1-line differences are likely trailing newlines or formatting. These can probably be ignored, but review if you want to preserve exact formatting
6. **Test classes** - Verify if the legacy test classes have any unique test cases not in the current version

## Next Steps

To see detailed differences for a specific file:
```powershell
git stash show -p -- "path/to/file"
```

To extract a specific file from the stash:
```powershell
git checkout stash@{0} -- "path/to/file"
```

