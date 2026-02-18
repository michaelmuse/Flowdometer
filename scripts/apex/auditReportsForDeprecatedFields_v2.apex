/**
 * Audit reports for ACTUAL deprecated field API names
 */

System.debug('=== Auditing for Deprecated Field API Names ===');

// Deprecated API names (without namespace)
Set<String> deprecatedFields = new Set<String>{
    'Breach_happens_at__c',
    'Created_by_Me__c',
    'Ending_Timestamp_or_NOW__c',
    'Flow_Goal_ID__c',
    'Goal_Breached__c',
    'Handle_Time_vs_Goal__c',
    'Handle_Time_over_Weekend_Days__c',
    'Handle_Time_Weekdays__c',
    'Initial_Timestamp_or_CREATED__c',
    'Next_Step_vs_Goal_Next_Step__c',
    'Progress_Bar_Elapsed_Color__c',
    'Progress_Bar_Remaining_Color__c',
    'Step_is_currently_active__c',
    'Sequence_and_Initial_Field_Value__c',
    'Start_Date__c',
    'Time_since_breach_in_hrs__c'
};

List<Report> flowdometerReports = [
    SELECT Id, Name, DeveloperName
    FROM Report
    WHERE FolderName = 'Flowdometer Reports'
    ORDER BY Name
];

System.debug('Found ' + flowdometerReports.size() + ' reports');
System.debug('');

Integer reportsWithDeprecated = 0;
Map<String, List<String>> reportFieldMap = new Map<String, List<String>>();

// Audit each report
for (Report rpt : flowdometerReports) {
    try {
        // Attempt to describe the report (checks for field errors)
        Reports.ReportDescribeResult describeResult = Reports.ReportManager.describeReport(rpt.Id);
        
        // Check if report uses deprecated fields
        String reportMetadata = JSON.serialize(describeResult);
        List<String> foundFields = new List<String>();
        
        for (String deprecatedField : deprecatedFields) {
            if (reportMetadata.contains(deprecatedField)) {
                foundFields.add(deprecatedField);
            }
        }
        
        if (!foundFields.isEmpty()) {
            reportsWithDeprecated++;
            reportFieldMap.put(rpt.Name, foundFields);
            System.debug('⚠️  ' + rpt.Name);
            for (String f : foundFields) {
                System.debug('     • ' + f);
            }
        } else {
            System.debug('✓ ' + rpt.Name);
        }
        
    } catch (Exception e) {
        System.debug('✗ ERROR: ' + rpt.Name + ' - ' + e.getMessage());
    }
}

// Summary
System.debug('');
System.debug('=== Summary ===');
System.debug('Total Reports: ' + flowdometerReports.size());
System.debug('Reports Using Deprecated Fields: ' + reportsWithDeprecated);
System.debug('Reports WITHOUT Deprecated Fields: ' + (flowdometerReports.size() - reportsWithDeprecated));

if (reportsWithDeprecated == 0) {
    System.debug('');
    System.debug('✅ NO REPORTS USE DEPRECATED FIELD API NAMES!');
    System.debug('The deprecated fields are safe to delete.');
} else {
    System.debug('');
    System.debug('⚠️  These reports will break if deprecated fields are deleted:');
    for (String rptName : reportFieldMap.keySet()) {
        System.debug('  - ' + rptName);
        for (String field : reportFieldMap.get(rptName)) {
            System.debug('      • ' + field);
        }
    }
}
