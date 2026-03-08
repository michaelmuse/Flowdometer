@IsTest
private class FlowdometerAuthServiceTest {

    private class RoutingMock implements HttpCalloutMock {
        Map<String, HttpCalloutMock> mocks = new Map<String, HttpCalloutMock>();

        void register(String urlFragment, Integer code, String body) {
            mocks.put(urlFragment, new SingleMock(code, body));
        }

        public HTTPResponse respond(HTTPRequest req) {
            String endpoint = req.getEndpoint();
            for (String fragment : mocks.keySet()) {
                if (endpoint.contains(fragment)) {
                    return mocks.get(fragment).respond(req);
                }
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setBody('No mock registered for: ' + endpoint);
            return res;
        }
    }

    private class SingleMock implements HttpCalloutMock {
        Integer code;
        String body;
        SingleMock(Integer code, String body) {
            this.code = code;
            this.body = body;
        }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setBody(body != null ? body : '');
            return res;
        }
    }

    static void injectTestCredentials() {
        FlowdometerTokenService.testClientId     = 'TEST_CLIENT_ID';
        FlowdometerTokenService.testClientSecret  = 'TEST_CLIENT_SECRET';
    }

    // ── checkConnectionStatus ──────────────────────────────────

    @IsTest
    static void checkConnectionStatus_connected() {
        injectTestCredentials();
        RoutingMock mock = new RoutingMock();
        mock.register('/services/oauth2/token', 200,
            '{"access_token":"mock_token_abc","scope":"api","token_type":"Bearer"}');
        mock.register('/limits', 200,
            '{"DailyApiRequests":{"Max":15000,"Remaining":14999}}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        FlowdometerAuthService.ConnectionStatus status =
            FlowdometerAuthService.checkConnectionStatus();
        Test.stopTest();

        System.assertEquals(true, status.connected);
        System.assertEquals(200, status.httpStatus);
        System.assertEquals('Connected', status.message);
    }

    @IsTest
    static void checkConnectionStatus_token_exchange_fails() {
        injectTestCredentials();
        RoutingMock mock = new RoutingMock();
        mock.register('/services/oauth2/token', 400,
            '{"error":"invalid_grant","error_description":"no client credentials user enabled"}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        FlowdometerAuthService.ConnectionStatus status =
            FlowdometerAuthService.checkConnectionStatus();
        Test.stopTest();

        System.assertEquals(false, status.connected);
        System.assert(status.errorDetails.contains('Complete Setup'),
            'Should advise running Complete Setup');
    }

    @IsTest
    static void checkConnectionStatus_api_call_fails() {
        injectTestCredentials();
        RoutingMock mock = new RoutingMock();
        mock.register('/services/oauth2/token', 200,
            '{"access_token":"mock_token_abc","scope":"api","token_type":"Bearer"}');
        mock.register('/limits', 500, '{"message":"Server Error"}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        FlowdometerAuthService.ConnectionStatus status =
            FlowdometerAuthService.checkConnectionStatus();
        Test.stopTest();

        System.assertEquals(false, status.connected);
        System.assertEquals(500, status.httpStatus);
    }

    // ── completeSetup ──────────────────────────────────────────

    @IsTest
    static void completeSetup_success() {
        String successResponse =
            '<?xml version="1.0" encoding="UTF-8"?>'
            + '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'
            + ' xmlns="http://soap.sforce.com/2006/04/metadata">'
            + '<soapenv:Body><updateMetadataResponse><result>'
            + '<fullName>Flowdometer_ECA_oauth_defaultPolicy</fullName>'
            + '<success>true</success>'
            + '</result></updateMetadataResponse></soapenv:Body></soapenv:Envelope>';

        Test.setMock(HttpCalloutMock.class, new SingleMock(200, successResponse));

        Test.startTest();
        FlowdometerAuthService.completeSetup('MOCK_SESSION_ID');
        Test.stopTest();
    }

    @IsTest
    static void completeSetup_failure_throws() {
        String failResponse =
            '<?xml version="1.0" encoding="UTF-8"?>'
            + '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'
            + ' xmlns="http://soap.sforce.com/2006/04/metadata">'
            + '<soapenv:Body><updateMetadataResponse><result>'
            + '<fullName>Flowdometer_ECA_oauth_defaultPolicy</fullName>'
            + '<success>false</success>'
            + '<errors><message>Invalid user</message>'
            + '<statusCode>INVALID_CROSS_REFERENCE_KEY</statusCode></errors>'
            + '</result></updateMetadataResponse></soapenv:Body></soapenv:Envelope>';

        Test.setMock(HttpCalloutMock.class, new SingleMock(200, failResponse));

        Test.startTest();
        Boolean caught = false;
        try {
            FlowdometerAuthService.completeSetup('MOCK_SESSION_ID');
        } catch (AuraHandledException e) {
            caught = true;
            System.assert(e.getMessage().contains('Invalid user'),
                'Should contain the SOAP error message');
        }
        Test.stopTest();

        System.assert(caught, 'Should throw AuraHandledException on failure');
    }

    @IsTest
    static void completeSetup_rejects_non_admin() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User stdUser = new User(
            ProfileId = stdProfile.Id,
            Username = 'flowtest_nonadmin_' + System.now().getTime() + '@flowdometer.test',
            Email = 'nonadmin@flowdometer.test',
            LastName = 'NonAdmin',
            Alias = 'nonadm',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert stdUser;

        Test.startTest();
        Boolean caught = false;
        System.runAs(stdUser) {
            try {
                FlowdometerAuthService.completeSetup('MOCK_SESSION_ID');
            } catch (AuraHandledException e) {
                caught = true;
                System.assert(e.getMessage().contains('Customize Application'),
                    'Should reference required permission');
            }
        }
        Test.stopTest();
        System.assert(caught, 'Should throw AuraHandledException for non-admin user');
    }

    // ── SOAP envelope builder ──────────────────────────────────

    @IsTest
    static void buildEnvelope_contains_required_elements() {
        String envelope = FlowdometerAuthService.buildUpdateMetadataEnvelope(
            'SESSION123', 'TestPolicy', 'ns__TestECA', 'admin@test.com'
        );

        System.assert(envelope.contains('SESSION123'), 'Should contain session ID');
        System.assert(envelope.contains('TestPolicy'), 'Should contain policy name');
        System.assert(envelope.contains('ns__TestECA'), 'Should contain ECA reference');
        System.assert(envelope.contains('admin@test.com'), 'Should contain admin username');
        System.assert(envelope.contains('isClientCredentialsFlowEnabled'), 'Should set client creds flag');
    }
}
