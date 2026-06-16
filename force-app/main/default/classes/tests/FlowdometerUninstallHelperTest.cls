@isTest
private class FlowdometerUninstallHelperTest {

    /** Mock for the Metadata API SOAP deleteMetadata callout with a
     *  configurable number of <success>true</success> results. */
    private class DeleteMetadataMock implements HttpCalloutMock {
        private Integer statusCode;
        private Integer successes;
        DeleteMetadataMock(Integer statusCode, Integer successes) {
            this.statusCode = statusCode;
            this.successes  = successes;
        }
        public HttpResponse respond(HttpRequest req) {
            String body = '<soapenv:Envelope><soapenv:Body><deleteMetadataResponse>';
            for (Integer i = 0; i < successes; i++) {
                body += '<result><success>true</success></result>';
            }
            body += '</deleteMetadataResponse></soapenv:Body></soapenv:Envelope>';
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    /** Endpoint-aware mock so the enqueued FlowDeactivator (token + Tooling
     *  callouts) and any SOAP deleteMetadata run cleanly within test scope. */
    private class UnifiedMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String ep = req.getEndpoint();
            if (ep.contains('/services/oauth2/token')) {
                res.setBody('{"access_token":"mocktoken","instance_url":"https://example.my.salesforce.com"}');
            } else if (ep.contains('/services/Soap/m/')) {
                res.setBody('<soapenv:Envelope><soapenv:Body><deleteMetadataResponse>'
                    + '</deleteMetadataResponse></soapenv:Body></soapenv:Envelope>');
            } else {
                res.setBody('{"records":[]}');
            }
            return res;
        }
    }

    @isTest
    static void deleteMetadataItems_countsSuccesses() {
        Test.setMock(HttpCalloutMock.class, new DeleteMetadataMock(200, 2));
        Test.startTest();
        Integer removed = FlowdometerUninstallHelper.deleteMetadataItems(
            'CustomField',
            new List<String>{ 'Opportunity.Stage_Flow__c', 'Contract.Status_Flow__c' },
            'fake-session-id');
        Test.stopTest();
        System.assertEquals(2, removed, 'Should report two deleted components');
    }

    @isTest
    static void deleteMetadataItems_httpErrorReturnsZero() {
        Test.setMock(HttpCalloutMock.class, new DeleteMetadataMock(500, 0));
        Test.startTest();
        Integer removed = FlowdometerUninstallHelper.deleteMetadataItems(
            'CustomField',
            new List<String>{ 'Opportunity.Stage_Flow__c' },
            'fake-session-id');
        Test.stopTest();
        System.assertEquals(0, removed, 'HTTP error should yield zero removals');
    }

    @isTest
    static void buildDeleteMetadataEnvelope_includesTypeAndMembers() {
        String env = FlowdometerUninstallHelper.buildDeleteMetadataEnvelope(
            'sid-123', 'CustomField', new List<String>{ 'Opportunity.Stage_Flow__c' });
        System.assert(env.contains('<met:type>CustomField</met:type>'), 'type present');
        System.assert(env.contains('<met:fullNames>Opportunity.Stage_Flow__c</met:fullNames>'), 'member present');
        System.assert(env.contains('<met:sessionId>sid-123</met:sessionId>'), 'session present');
        System.assert(env.contains('deleteMetadata'), 'operation present');
    }

    @isTest
    static void discoverForwardLookupFields_excludesPackagedFields() {
        List<String> members = FlowdometerUninstallHelper.discoverForwardLookupFields();
        for (String m : members) {
            System.assert(!m.contains('Flowdometer__'), 'Packaged fields must be excluded: ' + m);
        }
    }

    @isTest
    static void prepareForUninstall_adminSucceeds() {
        Test.setMock(HttpCalloutMock.class, new UnifiedMock());
        Test.startTest();
        FlowdometerUninstallHelper.UninstallResponse resp =
            FlowdometerUninstallHelper.prepareForUninstall('fake-session-id');
        Test.stopTest(); // enqueued FlowDeactivator runs here, within mock scope
        System.assertEquals(true, resp.success, 'Admin run should succeed');
        System.assertEquals(9, resp.deactivatedCount, 'All flows queued for deactivation');
    }

    @isTest
    static void prepareForUninstall_nonAdminRejected() {
        Profile std = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'stdu',
            Email = 'flowdometer.uninstall.test@example.com.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'NonAdmin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = std.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = 'flowdometer.uninstall.' + System.now().getTime() + '@example.com.invalid');
        insert u;

        Boolean threw = false;
        System.runAs(u) {
            try {
                FlowdometerUninstallHelper.prepareForUninstall('fake-session-id');
            } catch (AuraHandledException e) {
                threw = true;
            }
        }
        System.assertEquals(true, threw, 'Non-admin must be rejected');
    }

    @isTest
    static void deactivateFlows_returnsCount() {
        Test.setMock(HttpCalloutMock.class, new UnifiedMock());
        Test.startTest();
        Integer count = FlowdometerUninstallHelper.deactivateFlows();
        Test.stopTest();
        System.assertEquals(9, count, 'deactivateFlows returns flow count');
    }

    @isTest
    static void deactivateFlowsRest_succeeds() {
        Test.setMock(HttpCalloutMock.class, new UnifiedMock());
        Test.startTest();
        FlowdometerUninstallHelper.UninstallResponse rest =
            FlowdometerUninstallHelper.deactivateFlowsREST();
        Test.stopTest();
        System.assertEquals(true, rest.success, 'REST entry point succeeds');
        System.assertEquals(9, rest.deactivatedCount, 'REST reports flow count');
    }
}
