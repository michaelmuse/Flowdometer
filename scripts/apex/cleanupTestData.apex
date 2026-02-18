/**
 * Cleanup test data created by seedTestData.apex
 * 
 * Run this in Anonymous Apex:
 * Execute Anonymous: scripts/apex/cleanupTestData.apex
 * 
 * WARNING: This will delete ALL test records created by the seed script!
 */

System.debug('=== Starting Flowdometer Test Data Cleanup ===');

// Delete in reverse order of creation (respecting relationships)
Integer totalDeleted = 0;

// 1. Delete Step Trackers and Goals (all test steps will be deleted via Flow cascade)
// Since Steps have Master-Detail to Flow, they'll be automatically deleted when we delete Flows
System.debug('Steps will be deleted automatically via Flow cascade delete');

// 2. Delete Flow Trackers and Goals (by opportunity lookups and test data timeframe)
List<Flow__c> flows = [
    SELECT Id 
    FROM Flow__c 
    WHERE Opportunity__c IN (SELECT Id FROM Opportunity WHERE Name LIKE 'Test Opportunity%')
    OR (Tracked_Object__c = 'Opportunity' AND CreatedDate = TODAY)
];
if (!flows.isEmpty()) {
    delete flows;
    totalDeleted += flows.size();
    System.debug('Deleted ' + flows.size() + ' Flows (and cascade deleted Steps)');
}

// 3. Delete Test Opportunities
List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE Name LIKE 'Test Opportunity%'];
if (!opps.isEmpty()) {
    delete opps;
    totalDeleted += opps.size();
    System.debug('Deleted ' + opps.size() + ' Opportunities');
}

System.debug('=== Cleanup Complete ===');
System.debug('Total records deleted: ' + totalDeleted);
