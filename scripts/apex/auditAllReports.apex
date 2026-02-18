/**
 * Audit all Flowdometer reports - Test that they run without errors
 * 
 * Run this in Anonymous Apex:
 * Execute Anonymous: scripts/apex/auditAllReports.apex
 * 
 * This script will:
 * 1. Query all reports in the Flowdometer Reports folder
 * 2. Attempt to run each report programmatically
 * 3. Report which reports succeed/fail
 * 4. Identify reports using deprecated fields
 * 
 * NOTE: Some reports may show "No data" - that's OK! We're checking for errors.
 */

System.debug('=== Starting Flowdometer Report Audit ===');
System.debug('');

// Query all reports in Flowdometer Reports folder
List<Report> flowdometerReports = [
    SELECT Id, Name, DeveloperName, FolderName
    FROM Report
    WHERE FolderName = 'Flowdometer Reports'
    ORDER BY Name
];

System.debug('Found ' + flowdometerReports.size() + ' reports in Flowdometer Reports folder');
System.debug('');

// Track results
Integer successCount = 0;
Integer failCount = 0;
List<String> failedReports = new List<String>();
List<String> deprecatedFieldReports = new List<String>();

// Deprecated fields to check for
Set<String> deprecatedFields = new Set<String>{
    'Goal_Breached__c',
    'Breach_happens_at__c',
    'Time_since_breach_in_hrs__c',
    'Created_by_Me__c',
    'Start_Date__c',
    'Handle_Time_over_Weekend_Days__c',
    'Handle_Time_Weekdays__c',
    'Sequence_and_Initial_Field_Value__c',
    'Step_is_currently_active__c',
    'Progress_Bar_Elapsed_Color__c',
    'Progress_Bar_Remaining_Color__c',
    'Next_Step_vs_Goal_Next_Step__c',
    'Ending_Timestamp_or_NOW__c',
    'Initial_Timestamp_or_CREATED__c',
    'Flow_Goal_ID__c',
    'Handle_Time_vs_Goal__c'
};

// Audit each report
for (Report rpt : flowdometerReports) {
    try {
        // Attempt to describe the report (checks for field errors)
        Reports.ReportDescribeResult describeResult = Reports.ReportManager.describeReport(rpt.Id);
        
        // Check if report uses deprecated fields
        Boolean usesDeprecatedFields = false;
        String reportMetadata = JSON.serialize(describeResult);
        for (String deprecatedField : deprecatedFields) {
            if (reportMetadata.contains(deprecatedField)) {
                usesDeprecatedFields = true;
                if (!deprecatedFieldReports.contains(rpt.Name)) {
                    deprecatedFieldReports.add(rpt.Name);
                }
            }
        }
        
        // Try to run the report (limited to 10 rows)
        Reports.ReportResults results = Reports.ReportManager.runReport(rpt.Id, false);
        
        successCount++;
        String status = usesDeprecatedFields ? '[USES DEPRECATED FIELDS]' : '[OK]';
        System.debug('✓ ' + status + ' ' + rpt.Name);
        
    } catch (Exception e) {
        failCount++;
        failedReports.add(rpt.Name + ' - ' + e.getMessage());
        System.debug('✗ [FAILED] ' + rpt.Name);
        System.debug('   Error: ' + e.getMessage());
    }
}

// Summary
System.debug('');
System.debug('=== Report Audit Summary ===');
System.debug('Total Reports: ' + flowdometerReports.size());
System.debug('Successful: ' + successCount);
System.debug('Failed: ' + failCount);
System.debug('Using Deprecated Fields: ' + deprecatedFieldReports.size());
System.debug('');

if (failCount > 0) {
    System.debug('Failed Reports:');
    for (String failed : failedReports) {
        System.debug('  - ' + failed);
    }
    System.debug('');
}

if (deprecatedFieldReports.size() > 0) {
    System.debug('Reports Using Deprecated Fields (will break after Phase 6):');
    for (String rptName : deprecatedFieldReports) {
        System.debug('  - ' + rptName);
    }
    System.debug('');
}

// Get unreferenced reports from items_to_deprecate.md
List<String> unreferencedReports = new List<String>{
    'Breaching_Soon_25_time_remaining_zDw',
    'Breaching_today_b3w',
    'Queue_Duration_total_by_Person_9ZL',
    'Upcoming_Breaches_jUs',
    'Weekly_Average_Total_Handle_Time_zmU',
    'Weekly_Breach_Count_by_Step_QO0',
    'Weekly_wait_time_HMR',
    'Yesterdays_Breaches_VJm',
    'Weekly_Breach_Duration_by_Step_bGt',
    'Weekly_Handle_Time_Vs_Goal_2Py',
    'Weekly_Queue_Size_by_Step_QiY',
    'Response_Time_hours_uhi',
    'Slowest_Steps_Trending_fuy',
    'Success_Rate_by_Step_All_Time_3qD',
    'Time_To_First_Step_JUQ',
    'Total_Flow_Handle_Time_D6d',
    'Breach_Rate_Flows_wKr',
    'Cycle_Time_over_the_last_two_NIh'
};

System.debug('Unreferenced Reports (not used in dashboards - per items_to_deprecate.md):');
Integer unreferencedFound = 0;
for (String unreferencedName : unreferencedReports) {
    for (Report rpt : flowdometerReports) {
        if (rpt.DeveloperName.contains(unreferencedName) || rpt.Name.contains(unreferencedName)) {
            unreferencedFound++;
            System.debug('  - ' + rpt.Name + ' (' + rpt.DeveloperName + ')');
            break;
        }
    }
}
System.debug('Found ' + unreferencedFound + ' of ' + unreferencedReports.size() + ' unreferenced reports');
System.debug('');

// Recommendations
System.debug('=== Recommendations ===');
if (failCount > 0) {
    System.debug('❗ Fix failed reports before proceeding with deprecation');
}
if (deprecatedFieldReports.size() > 0) {
    System.debug('⚠️  ' + deprecatedFieldReports.size() + ' reports use deprecated fields - these will break after Phase 6');
    System.debug('   Consider updating these reports or marking them for deletion');
}
if (unreferencedFound > 0) {
    System.debug('💡 ' + unreferencedFound + ' unreferenced reports can be safely deleted');
    System.debug('   These reports are not used in any dashboards');
}
if (successCount == flowdometerReports.size() && deprecatedFieldReports.size() == 0) {
    System.debug('✅ All reports are working and ready for Phase 6 deprecation');
}

System.debug('');
System.debug('=== Audit Complete ===');
System.debug('Next Steps:');
System.debug('  1. Review failed reports (if any) and fix field references');
System.debug('  2. Decide which unreferenced reports to delete');
System.debug('  3. Update/delete reports using deprecated fields');
System.debug('  4. Proceed with Phase 5.2 (User Review)');
