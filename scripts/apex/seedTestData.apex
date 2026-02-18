/**
 * Seed test data for Flowdometer - Creates sample Flow and Step records
 * 
 * Run: sf apex run --file scripts/apex/seedTestData.apex --target-org PBODevHub
 */

System.debug('=== Flowdometer Test Data Seed ===');

// Get Record Type IDs
Id flowGoalRT = Schema.SObjectType.Flow__c.getRecordTypeInfosByDeveloperName().get('Goal').getRecordTypeId();
Id flowTrackerRT = Schema.SObjectType.Flow__c.getRecordTypeInfosByDeveloperName().get('Tracker').getRecordTypeId();
Id stepGoalRT = Schema.SObjectType.Step__c.getRecordTypeInfosByDeveloperName().get('Goal').getRecordTypeId();
Id stepTrackerRT = Schema.SObjectType.Step__c.getRecordTypeInfosByDeveloperName().get('Tracker').getRecordTypeId();

// Create Opportunities (dates in the past for reporting)
List<Opportunity> opps = new List<Opportunity>();
for (Integer i = 1; i <= 5; i++) {
    opps.add(new Opportunity(
        Name = 'Test Opp ' + i,
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(-60 + (i * 10)), // Past dates spread over 50 days
        Amount = 10000 * i
    ));
}
insert opps;
System.debug('✓ ' + opps.size() + ' Opportunities');

// Create Flow Goals
List<Flow__c> flowGoals = new List<Flow__c>();
flowGoals.add(new Flow__c(
    RecordTypeId = flowGoalRT,
    Tracked_Object__c = 'Opportunity',
    Tracked_Field_Name__c = 'StageName',
    Match_Goal_with_Flows__c = true
));
flowGoals.add(new Flow__c(
    RecordTypeId = flowGoalRT,
    Tracked_Object__c = 'Opportunity',
    Tracked_Field_Name__c = 'StageName',
    Match_Goal_with_Flows__c = true
));
insert flowGoals;
System.debug('✓ ' + flowGoals.size() + ' Flow Goals');

// Create Step Goals
String[] stages = new String[]{'Prospecting', 'Qualification', 'Needs Analysis', 'Value Proposition', 'Negotiation/Review', 'Closed Won', 'Closed Lost'};
List<Step__c> stepGoals = new List<Step__c>();

for (Integer goalIdx = 0; goalIdx < flowGoals.size(); goalIdx++) {
    Decimal goalHours = (goalIdx == 0) ? 72 : 36; // Standard=72hrs, Fast=36hrs
    for (Integer i = 0; i < stages.size(); i++) {
        stepGoals.add(new Step__c(
            RecordTypeId = stepGoalRT,
            Flow__c = flowGoals[goalIdx].Id,
            Field_Value_Initial__c = stages[i],
            Field_Value_Ending__c = (i < stages.size() - 1) ? stages[i + 1] : stages[i],
            Sequence__c = i + 1,
            GoalHandleTimeHrs__c = goalHours,
            Terminal_Stage__c = (i >= stages.size() - 2)
        ));
    }
}
insert stepGoals;
System.debug('✓ ' + stepGoals.size() + ' Step Goals');

// Link Step Goals (Next/Last)
List<Step__c> goalsToUpdate = new List<Step__c>();
for (Integer i = 0; i < stepGoals.size(); i++) {
    Step__c currentGoal = stepGoals[i];
    Boolean needsUpdate = false;
    
    // Link to Next Step Goal (if same Flow)
    if (i + 1 < stepGoals.size() && stepGoals[i+1].Flow__c == currentGoal.Flow__c) {
        currentGoal.Next_Step__c = stepGoals[i+1].Id;
        needsUpdate = true;
    }
    // Link to Last Step Goal (if same Flow)
    if (i > 0 && stepGoals[i-1].Flow__c == currentGoal.Flow__c) {
        currentGoal.Last_Step__c = stepGoals[i-1].Id;
        needsUpdate = true;
    }
    if (needsUpdate) goalsToUpdate.add(currentGoal);
}
update goalsToUpdate;

// Create Flow Trackers
List<Flow__c> flowTrackers = new List<Flow__c>();
for (Integer i = 0; i < opps.size(); i++) {
    Id goalId = (Math.mod(i, 2) == 0) ? flowGoals[0].Id : flowGoals[1].Id;
    flowTrackers.add(new Flow__c(
        RecordTypeId = flowTrackerRT,
        Tracked_Object__c = 'Opportunity',
        Tracked_Field_Name__c = 'StageName',
        Tracked_Object_ID__c = opps[i].Id,
        Name_of_Tracked_Record__c = opps[i].Name,
        Opportunity__c = opps[i].Id,
        Goal__c = goalId
    ));
}
insert flowTrackers;
System.debug('✓ ' + flowTrackers.size() + ' Flow Trackers');

// Create Step Trackers (mix of completed and in-progress)
List<Step__c> stepTrackers = new List<Step__c>();

for (Integer flowIdx = 0; flowIdx < flowTrackers.size(); flowIdx++) {
    Flow__c flow = flowTrackers[flowIdx];
    
    // First 2 flows are COMPLETED (all stages), rest are in-progress
    Boolean isCompleted = (flowIdx < 2);
    Integer numSteps = isCompleted ? stages.size() : (3 + (Integer)(Math.random() * 3));
    
    // Completed flows start 60 days ago, in-progress start 30 days ago
    DateTime baseTime = isCompleted ? DateTime.now().addDays(-60) : DateTime.now().addDays(-30);
    DateTime stepStart = baseTime.addHours(flowIdx * 12);
    
    for (Integer i = 0; i < numSteps && i < stages.size(); i++) {
        Boolean isLastStep = (i == numSteps - 1);
        Boolean isClosedWon = (stages[i] == 'Closed Won');
        DateTime stepEnd = !isLastStep ? stepStart.addHours(24 + (Integer)(Math.random() * 48)) : null;
        
        // Calculate Final_Handle_Time__c in days (time between start and end, or start and now if still active)
        Decimal finalHandleTime = null;
        if (stepEnd != null) {
            // Completed step: calculate days between start and end
            Long milliseconds = stepEnd.getTime() - stepStart.getTime();
            finalHandleTime = milliseconds / (1000.0 * 60 * 60 * 24); // Convert to days
        } else if (isLastStep) {
            // Active terminal step: calculate days from start to now
            Long milliseconds = DateTime.now().getTime() - stepStart.getTime();
            finalHandleTime = milliseconds / (1000.0 * 60 * 60 * 24); // Convert to days
        }
        
        Step__c step = new Step__c(
            RecordTypeId = stepTrackerRT,
            Flow__c = flow.Id,
            Field_Value_Initial__c = stages[i],
            Field_Value_Ending__c = !isLastStep ? stages[i + 1] : null,
            InitialTS__c = stepStart,
            EndingTS__c = stepEnd,
            Sequence__c = i + 1,
            Success__c = isClosedWon, // Mark Closed Won as successful
            Terminal_Stage__c = (isClosedWon || stages[i] == 'Closed Lost'), // Terminal stages
            Final_Handle_Time__c = finalHandleTime
        );
        
        // Link to goal
        for (Step__c goal : stepGoals) {
            if (goal.Flow__c == flow.Goal__c && goal.Field_Value_Initial__c == stages[i]) {
                step.Step_Goal__c = goal.Id;
                break;
            }
        }
        
        stepTrackers.add(step);
        if (stepEnd != null) stepStart = stepEnd;
    }
}
insert stepTrackers;
System.debug('✓ ' + stepTrackers.size() + ' Step Trackers (2 completed flows, ' + (flowTrackers.size() - 2) + ' in-progress)');

// Link Step Trackers (Next/Last)
List<Step__c> trackersToUpdate = new List<Step__c>();
for (Integer i = 0; i < stepTrackers.size(); i++) {
    Step__c currentStep = stepTrackers[i];
    Boolean needsUpdate = false;
    
    // Link to Next Step (if same Flow)
    if (i + 1 < stepTrackers.size() && stepTrackers[i+1].Flow__c == currentStep.Flow__c) {
        currentStep.Next_Step__c = stepTrackers[i+1].Id;
        needsUpdate = true;
    }
    // Link to Last Step (if same Flow)
    if (i > 0 && stepTrackers[i-1].Flow__c == currentStep.Flow__c) {
        currentStep.Last_Step__c = stepTrackers[i-1].Id;
        needsUpdate = true;
    }
    
    if (needsUpdate) trackersToUpdate.add(currentStep);
}
update trackersToUpdate;

System.debug('');
System.debug('=== COMPLETE ===');
System.debug('Created: ' + opps.size() + ' Opps, ' + flowGoals.size() + ' Flow Goals, ' + 
             flowTrackers.size() + ' Flow Trackers, ' + stepGoals.size() + ' Step Goals, ' + 
             stepTrackers.size() + ' Step Trackers');
System.debug('Next: Run reports in UI or execute scripts/apex/auditAllReports.apex');
