/**
 * Acquires an OAuth access token for same-org API calls using the
 * packaged ECA's client_credentials flow.  Reads the client ID and
 * secret from Protected Custom Metadata (Eca_Secret__mdt) which is
 * only accessible to code inside the managed-package namespace.
 *
 * Tokens are cached for the duration of the Apex transaction to avoid
 * redundant callouts when multiple classes need API access in the same
 * execution context.
 */
public with sharing class FlowdometerTokenService {

    @TestVisible private static String testClientId;
    @TestVisible private static String testClientSecret;

    private static TokenResult cachedToken;

    private static final Integer MAX_RETRIES = 1;
    private static final Integer TIMEOUT_MS  = 15000;

    public class TokenResult {
        public Boolean success;
        public String accessToken;
        public String errorMessage;
    }

    /**
     * Returns a valid access token, using a transaction-scoped cache
     * to avoid redundant token exchanges within the same execution.
     */
    public static TokenResult getToken() {
        if (cachedToken != null && cachedToken.success) {
            return cachedToken;
        }

        cachedToken = requestNewToken();
        return cachedToken;
    }

    /**
     * Forces a fresh token exchange, bypassing the cache.
     * Use after a 401 response to recover from an expired token.
     */
    public static TokenResult refreshToken() {
        cachedToken = null;
        return getToken();
    }

    @TestVisible
    private static void clearCache() {
        cachedToken = null;
    }

    private static TokenResult requestNewToken() {
        TokenResult result = new TokenResult();
        result.success = false;

        String clientId;
        String clientSecret;

        if (Test.isRunningTest() && testClientId != null) {
            clientId     = testClientId;
            clientSecret = testClientSecret;
        } else {
            Eca_Secret__mdt secret;
            try {
                secret = [
                    SELECT Client_Id__c, Client_Secret__c
                    FROM Eca_Secret__mdt
                    WHERE DeveloperName = 'Default'
                    LIMIT 1
                ];
            } catch (QueryException e) {
                result.errorMessage = 'Credential metadata not found. Package may need reinstallation.';
                return result;
            }
            clientId     = secret.Client_Id__c;
            clientSecret = secret.Client_Secret__c;
        }

        if (String.isBlank(clientId) || String.isBlank(clientSecret)) {
            result.errorMessage = 'Credential metadata is incomplete.';
            return result;
        }

        String endpoint = URL.getOrgDomainUrl().toExternalForm() + '/services/oauth2/token';
        String body = 'grant_type=client_credentials'
            + '&client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8')
            + '&client_secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8');

        HttpResponse res;
        Integer attempts = 0;

        while (attempts <= MAX_RETRIES) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(body);
            req.setTimeout(TIMEOUT_MS);

            try {
                res = new Http().send(req);
                break;
            } catch (CalloutException e) {
                attempts++;
                if (attempts > MAX_RETRIES) {
                    result.errorMessage = 'Token endpoint unreachable.';
                    return result;
                }
            }
        }

        if (res.getStatusCode() == 200) {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            result.accessToken = (String) parsed.get('access_token');
            result.success = true;
        } else {
            Map<String, Object> parsed;
            try {
                parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            } catch (Exception e) {
                parsed = new Map<String, Object>();
            }
            String oauthError = (String) parsed.get('error_description');
            if (String.isNotBlank(oauthError) && oauthError.containsIgnoreCase('no client credentials user')) {
                result.errorMessage = 'Client Credentials flow is not enabled. In Setup, open External Client App Manager, edit the Flowdometer ECA policies, and enable the Client Credentials Flow with a Run-As user.';
            } else {
                result.errorMessage = 'Token exchange failed (HTTP ' + res.getStatusCode() + ').';
            }
        }

        return result;
    }
}
