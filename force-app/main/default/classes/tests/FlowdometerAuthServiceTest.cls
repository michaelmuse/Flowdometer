/**
 * @description Tests for FlowdometerAuthService connection-check and setup helpers.
 * Uses HttpCalloutMock to simulate Named Credential callouts.
 */
@IsTest
private class FlowdometerAuthServiceTest {

    // Simple mock to control response status/body for any endpoint
    private class SimpleMock implements HttpCalloutMock {
        Integer code;
        String body;
        Map<String, String> headers;

        SimpleMock(Integer code, String body) {
            this.code = code;
            this.body = body;
            this.headers = new Map<String, String>();
            this.headers.put('Content-Type', 'application/json');
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setBody(body != null ? body : '');
            for (String h : headers.keySet()) {
                res.setHeader(h, headers.get(h));
            }
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        // Nothing required; we only mock callouts
    }

    @IsTest
    static void checkConnectionStatus_ok_200() {
        // Simulate successful GET /limits via Named Credential
        Test.setMock(HttpCalloutMock.class, new SimpleMock(200, '{"DailyApiRequests":{"Max":15000,"Remaining":14999}}'));

        Test.startTest();
        FlowdometerAuthService.ConnectionStatus status = FlowdometerAuthService.checkConnectionStatus();
        Test.stopTest();

        System.assertEquals(true, status.connected, 'Connected should be true on 200');
        System.assertEquals(200, status.httpStatus, 'HTTP 200 expected');
        System.assertEquals('Connected', status.message, 'Message should indicate Connected');
        System.assertNotEquals(null, status.orgDomainUrl, 'Org domain url should be returned');
        System.assertNotEquals(null, status.namedCredentialSetupUrl, 'NC setup URL should be returned');
        System.assertNotEquals(null, status.externalCredentialAuthUrl, 'EC auth URL should be returned');
    }

    @IsTest
    static void checkConnectionStatus_auth_required_401() {
        // Simulate 401 Unauthorized from limits call
        Test.setMock(HttpCalloutMock.class, new SimpleMock(401, '{"message":"Unauthorized"}'));

        Test.startTest();
        FlowdometerAuthService.ConnectionStatus status = FlowdometerAuthService.checkConnectionStatus();
        Test.stopTest();

        System.assertEquals(false, status.connected, 'Connected should be false on 401');
        System.assertEquals(401, status.httpStatus, 'HTTP 401 expected');
        System.assertEquals('Not Connected - Authorization Required', status.message, 'Auth required message expected');
        System.assert(status.errorDetails != null && status.errorDetails.contains('HTTP 401'), 'Should contain HTTP status code in error details');
    }

    @IsTest
    static void checkConnectionStatus_other_error_500() {
        // Simulate 500 from limits call
        Test.setMock(HttpCalloutMock.class, new SimpleMock(500, '{"message":"Server error"}'));

        Test.startTest();
        FlowdometerAuthService.ConnectionStatus status = FlowdometerAuthService.checkConnectionStatus();
        Test.stopTest();

        System.assertEquals(false, status.connected, 'Connected should be false on 500');
        System.assertEquals(500, status.httpStatus, 'HTTP 500 expected');
        System.assertEquals('Connection check failed', status.message, 'Generic failure message expected');
        System.assert(status.errorDetails != null && status.errorDetails.contains('HTTP 500'), 'Should contain HTTP status code in error details');
    }

    @IsTest
    static void getOrgDomainUrl_returns_value() {
        Test.startTest();
        String url = FlowdometerAuthService.getOrgDomainUrl();
        Test.stopTest();

        System.assertNotEquals(null, url, 'URL should not be null');
        System.assertEquals(true, url.startsWith('https://') || url.startsWith('http://'), 'URL should look like a URL');
    }

    @IsTest
    static void setup_links_return_values_even_when_callout_fails() {
        // For getNamedCredentialSetupUrl() we try a Tooling query via Named Credential.
        // Simulate failure so method falls back to Setup home; ensure still returns a URL.
        Test.setMock(HttpCalloutMock.class, new SimpleMock(401, '{"message":"Unauthorized"}'));

        Test.startTest();
        String ncUrl = FlowdometerAuthService.getNamedCredentialSetupUrl();
        String ecUrl = FlowdometerAuthService.getExternalCredentialAuthUrl();
        Test.stopTest();

        System.assertNotEquals(null, ncUrl, 'NC setup URL should be non-null even on failure');
        System.assert(ncUrl.contains('/lightning/setup/NamedCredential/'), 'NC URL should point to Named Credential setup');
        System.assertNotEquals(null, ecUrl, 'EC auth URL should be non-null');
        System.assert(ecUrl.contains('/lightning/setup/ExternalCredentials/'), 'EC URL should point to External Credentials setup');
    }
}
