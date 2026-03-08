@IsTest
private class FlowdometerTokenServiceTest {

    private class TokenMock implements HttpCalloutMock {
        Integer statusCode;
        String body;
        Integer callCount = 0;

        TokenMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HTTPResponse respond(HTTPRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body != null ? body : '');
            return res;
        }
    }

    private class FailThenSucceedMock implements HttpCalloutMock {
        Integer callCount = 0;

        public HTTPResponse respond(HTTPRequest req) {
            callCount++;
            if (callCount == 1) {
                throw new CalloutException('Simulated timeout');
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token":"retry_token","scope":"api","token_type":"Bearer"}');
            return res;
        }
    }

    private class AlwaysFailMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new CalloutException('Simulated timeout');
        }
    }

    static void injectCredentials() {
        FlowdometerTokenService.testClientId     = 'TEST_CLIENT_ID';
        FlowdometerTokenService.testClientSecret  = 'TEST_CLIENT_SECRET';
    }

    // ── Success path ────────────────────────────────────────────

    @IsTest
    static void getToken_success() {
        injectCredentials();
        Test.setMock(HttpCalloutMock.class, new TokenMock(200,
            '{"access_token":"abc123","scope":"api","token_type":"Bearer"}'));

        Test.startTest();
        FlowdometerTokenService.TokenResult result = FlowdometerTokenService.getToken();
        Test.stopTest();

        System.assertEquals(true, result.success, 'Should succeed');
        System.assertEquals('abc123', result.accessToken, 'Should return the token');
        System.assertEquals(null, result.errorMessage, 'No error on success');
    }

    // ── "no client credentials user" specific error ─────────────

    @IsTest
    static void getToken_noClientCredentialsUser() {
        injectCredentials();
        Test.setMock(HttpCalloutMock.class, new TokenMock(400,
            '{"error":"invalid_grant","error_description":"no client credentials user enabled"}'));

        Test.startTest();
        FlowdometerTokenService.TokenResult result = FlowdometerTokenService.getToken();
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(result.errorMessage.contains('Complete Setup'),
            'Should advise running Complete Setup: ' + result.errorMessage);
    }

    // ── Generic non-200 error ───────────────────────────────────

    @IsTest
    static void getToken_genericFailure() {
        injectCredentials();
        Test.setMock(HttpCalloutMock.class, new TokenMock(500,
            '{"error":"server_error","error_description":"internal error"}'));

        Test.startTest();
        FlowdometerTokenService.TokenResult result = FlowdometerTokenService.getToken();
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(result.errorMessage.contains('500'),
            'Should include HTTP status: ' + result.errorMessage);
    }

    // ── Non-200 with unparseable body ───────────────────────────

    @IsTest
    static void getToken_unparseableErrorBody() {
        injectCredentials();
        Test.setMock(HttpCalloutMock.class, new TokenMock(502, 'Bad Gateway'));

        Test.startTest();
        FlowdometerTokenService.TokenResult result = FlowdometerTokenService.getToken();
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(result.errorMessage.contains('502'),
            'Should fall back to HTTP status code');
    }

    // ── Transient failure + retry succeeds ──────────────────────

    @IsTest
    static void getToken_retryOnTransientFailure() {
        injectCredentials();
        FailThenSucceedMock mock = new FailThenSucceedMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        FlowdometerTokenService.TokenResult result = FlowdometerTokenService.getToken();
        Test.stopTest();

        System.assertEquals(true, result.success, 'Should succeed after retry');
        System.assertEquals('retry_token', result.accessToken);
        System.assertEquals(2, mock.callCount, 'Should have made 2 attempts');
    }

    // ── All retries exhausted ───────────────────────────────────

    @IsTest
    static void getToken_allRetriesExhausted() {
        injectCredentials();
        Test.setMock(HttpCalloutMock.class, new AlwaysFailMock());

        Test.startTest();
        FlowdometerTokenService.TokenResult result = FlowdometerTokenService.getToken();
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(result.errorMessage.contains('unreachable'),
            'Should report endpoint unreachable: ' + result.errorMessage);
    }

    // ── Cache: second call reuses cached token ──────────────────

    @IsTest
    static void getToken_cachesResult() {
        injectCredentials();
        TokenMock mock = new TokenMock(200,
            '{"access_token":"cached_token","scope":"api","token_type":"Bearer"}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        FlowdometerTokenService.TokenResult first  = FlowdometerTokenService.getToken();
        FlowdometerTokenService.TokenResult second = FlowdometerTokenService.getToken();
        Test.stopTest();

        System.assertEquals(true, first.success);
        System.assertEquals(true, second.success);
        System.assertEquals('cached_token', second.accessToken);
        System.assertEquals(1, mock.callCount,
            'Second call should use cache, not make another callout');
    }

    // ── refreshToken clears cache and re-fetches ────────────────

    @IsTest
    static void refreshToken_invalidatesCache() {
        injectCredentials();
        TokenMock mock = new TokenMock(200,
            '{"access_token":"fresh_token","scope":"api","token_type":"Bearer"}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        FlowdometerTokenService.getToken();
        FlowdometerTokenService.TokenResult refreshed = FlowdometerTokenService.refreshToken();
        Test.stopTest();

        System.assertEquals(true, refreshed.success);
        System.assertEquals(2, mock.callCount,
            'refreshToken should bypass cache and make a new callout');
    }

    // ── Blank credentials ───────────────────────────────────────

    @IsTest
    static void getToken_blankCredentials() {
        FlowdometerTokenService.testClientId     = '';
        FlowdometerTokenService.testClientSecret  = '';

        Test.startTest();
        FlowdometerTokenService.TokenResult result = FlowdometerTokenService.getToken();
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(result.errorMessage.contains('incomplete'),
            'Should report incomplete credentials: ' + result.errorMessage);
    }
}
