/**
 * Audit reports for ACTUAL deprecated field API names
 * Run: sf apex run --file scripts/apex/auditReportsForDeprecatedFields.apex --target-org PBODevHub
 */

System.debug('=== Auditing for Deprecated Field API Names ===');

// Deprecated API names
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

List<Report> reports = [SELECT Id, Name FROM Report WHERE FolderName = 'Flowdometer Reports' ORDER BY Name];
System.debug('Found ' + reports.size() + ' reports');

Integer reportsWithDeprecated = 0;
Map<String, List<String>> reportFieldMap = new Map<String, List<String>>();

for (Report rpt : reports) {
    try {
        Reports.ReportDescribeResult describeResult = Reports.ReportManager.describeReport(rpt.Id);
        String json = JSON.serialize(describeResult);
        List<String> found = new List<String>();
        
        for (String field : deprecatedFields) {
            if (json.contains(field)) {
                found.add(field);
            }
        }
        
        if (!found.isEmpty()) {
            reportsWithDeprecated++;
            reportFieldMap.put(rpt.Name, found);
            System.debug('⚠️  ' + rpt.Name);
            for (String f : found) {
                System.debug('     • ' + f);
            }
        }
    } catch (Exception e) {
        System.debug('✗ Error: ' + rpt.Name);
    }
}

System.debug('');
System.debug('=== Summary ===');
System.debug('Reports with deprecated fields: ' + reportsWithDeprecated + '/' + reports.size());
