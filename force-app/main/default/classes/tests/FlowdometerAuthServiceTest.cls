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
        System.assert(status.errorDetails.contains('Client Credentials'),
            'Should advise enabling the Client Credentials Flow');
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
}
