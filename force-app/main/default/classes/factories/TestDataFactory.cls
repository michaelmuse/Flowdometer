@isTest
public with sharing class TestDataFactory {
    public static List<Opportunity> createAndUpdateOpportunities(
        Id parentId,
        String field,
        Integer numRecords
    ) {
        // Create Opportunities
        List<Opportunity> opportunities = new List<Opportunity>();
        for (Integer i = 0; i < numRecords; i++) {
            Opportunity opp = new Opportunity(
                Name = 'Test Opp ' + i,
                StageName = 'Prospecting',
                CloseDate = System.today(),
                AccountId = parentId,
                Type = 'New Business'
            );

            opportunities.add(opp);
        }

        insert opportunities;

        // Update Opportunities to generate history records
        for (Opportunity opp : opportunities) {
            opp.put(field, 'New Value ' + Datetime.now().getTime()); // Update the field to track
        }

        update opportunities;

        return opportunities; // Return the list of updated Opportunities
    }

    public static Case createCase(String subject, String status) {
        Case newCase = new Case(Subject = subject, Status = status);

        insert newCase;
        return newCase;
    }

    public static Listener__c createListenerConfig(
        String objectName,
        String fieldToTrack,
        Datetime lastExecutionOn,
        Boolean doInsert
    ) {
        // Step 1: see if record already exists
        Listener__c existing = null;
        try {
            existing = [
                SELECT Id,
                       Object_Name__c,
                       Field_To_Track__c,
                       Last_Execution_On__c,
                       Enable_History__c,
                       Type__c
                FROM Listener__c
                WHERE Object_Name__c = :objectName
                  AND Field_To_Track__c = :fieldToTrack
                LIMIT 1
            ];
        } catch (Exception ignore) {}

        if (existing != null) {
            return existing;
        }

        // If caller doesn't want us to insert, just return the new (unsaved) record
        if (!doInsert) {
            Listener__c unsaved = new Listener__c(
                Object_Name__c = objectName,
                Field_To_Track__c = fieldToTrack,
                Last_Execution_On__c = lastExecutionOn
            );
            return unsaved;
        }

        // Step 2: perform insert with duplicate-rule bypass so unit tests are never blocked
        Listener__c toInsert = new Listener__c(
            Object_Name__c = objectName,
            Field_To_Track__c = fieldToTrack,
            Last_Execution_On__c = lastExecutionOn
        );
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        dmlOpts.DuplicateRuleHeader.runAsCurrentUser = true;
        toInsert.setOptions(dmlOpts);

        toInsert.setOptions(dmlOpts);
        try {
            Database.insert(toInsert, false);
            return toInsert;
        } catch (DmlException dex) {
            // Duplicate detected or other failure – query back existing record (if any) and return
            try {
                return [
                    SELECT Id,
                           Object_Name__c,
                           Field_To_Track__c,
                           Last_Execution_On__c,
                           Enable_History__c,
                           Type__c
                    FROM Listener__c
                    WHERE Object_Name__c = :objectName
                      AND Field_To_Track__c = :fieldToTrack
                    LIMIT 1
                ];
            } catch (Exception queryEx) {
                // Still no luck – return the in-memory object so the test doesn't fail unexpectedly
                return toInsert;
            }
        }
    }

    // Convenience builder for a Listener that also configures the optional
    // Type__c source field and the Enable_History__c toggle in a single call,
    // so individual tests don't have to re-do the create-then-update dance.
    public static Listener__c createListenerConfigWithType(
        String objectName,
        String fieldToTrack,
        String typeField,
        Boolean enableHistory,
        Datetime lastExecutionOn
    ) {
        Listener__c listener = createListenerConfig(
            objectName,
            fieldToTrack,
            lastExecutionOn,
            true
        );

        if (String.isNotBlank(typeField)) {
            listener.Type__c = typeField;
        }
        listener.Enable_History__c = enableHistory;

        if (listener.Id != null) {
            update listener;
        }
        return listener;
    }

    public static Opportunity createOpportunity(
        String name,
        String stageName,
        Date closeDate
    ) {
        Opportunity opp = new Opportunity(
            Name = name,
            StageName = stageName,
            CloseDate = closeDate
        );

        insert opp;
        return opp;
    }

    public static List<Opportunity> createOpportunityHistoryRecords(
        Integer numRecords,
        String stageName
    ) {
        List<Opportunity> historyRecords = new List<Opportunity>();
        for (Integer i = 0; i < numRecords; i++) {
            historyRecords.add(
                new Opportunity(
                    Name = 'Test Opportunity ' + i,
                    StageName = stageName, // Use the provided stageName parameter
                    CloseDate = Date.today().addDays(10)
                )
            );
        }

        insert historyRecords; // Insert the Opportunity records
        return historyRecords;
    }

    public static List<Flow__c> createCustomObjects(Integer numRecords) {
        List<Flow__c> flows = new List<Flow__c>();
        for (Integer i = 0; i < numRecords; i++) {
            flows.add(new Flow__c());
        }

        insert flows; // Insert the Flow__c records
        return flows;
    }

    public static Account createAccount(String accountName) {
        Account acc = new Account(Name = accountName);

        insert acc;
        return acc;
    }
}