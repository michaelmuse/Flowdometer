/**
 * Service class backing the Flowdometer Connection Setup LWC.
 *
 * checkConnectionStatus — acquires a client_credentials token through
 *                         FlowdometerTokenService and validates it against
 *                         the REST /limits endpoint. Session-free: the token
 *                         is minted by the packaged External Client App's
 *                         client-credentials flow, never UserInfo.getSessionId().
 *
 * Enabling the client-credentials flow and designating the Run-As user on the
 * packaged ECA is an admin-driven, one-time manual step performed in the
 * External Client App Manager (Setup). The package deliberately does NOT
 * automate it: per the Salesforce Secure Coding Guide, using a session id to
 * create or modify an External Client App via the Metadata/Tooling API is a
 * prohibited use case. The Connection Setup LWC guides the admin through the
 * manual step and detects completion by calling checkConnectionStatus.
 */
public with sharing class FlowdometerAuthService {

    private static final String API_VERSION = 'v65.0';

    public class ConnectionStatus {
        @AuraEnabled public Boolean connected   { get; set; }
        @AuraEnabled public Integer httpStatus   { get; set; }
        @AuraEnabled public String  message      { get; set; }
        @AuraEnabled public String  errorDetails { get; set; }
    }

    // ── Check Connection ───────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static ConnectionStatus checkConnectionStatus() {
        ConnectionStatus status = new ConnectionStatus();
        status.connected = false;
        status.message   = 'Not Connected';

        FlowdometerTokenService.TokenResult tokenResult = FlowdometerTokenService.getToken();

        if (!tokenResult.success) {
            status.httpStatus   = 0;
            status.errorDetails = tokenResult.errorMessage;
            return status;
        }

        String limitsUrl = URL.getOrgDomainUrl().toExternalForm()
            + '/services/data/' + API_VERSION + '/limits';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(limitsUrl);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + tokenResult.accessToken);
        req.setTimeout(10000);

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (CalloutException e) {
            status.httpStatus   = 0;
            status.errorDetails = 'API endpoint unreachable.';
            return status;
        }

        status.httpStatus = res.getStatusCode();

        if (res.getStatusCode() == 200) {
            status.connected = true;
            status.message   = 'Connected';
        } else {
            status.errorDetails = 'API call returned HTTP ' + res.getStatusCode() + '.';
        }

        return status;
    }
}
