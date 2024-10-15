public class TestDataFactory {
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

    public static Flowdometer__Listener__c createListenerConfig(
        String objectName,
        String fieldToTrack,
        Datetime lastExecutionOn,
        Boolean doInsert
    ) {
        Flowdometer__Listener__c listenerConfig = new Flowdometer__Listener__c(
            Flowdometer__Object_Name__c = objectName,
            Flowdometer__Field_To_Track__c = fieldToTrack,
            Flowdometer__Last_Execution_On__c = lastExecutionOn
        );

        if (doInsert) {
            insert listenerConfig;
        }

        return listenerConfig;
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
