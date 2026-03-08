/**
 * Service class backing the Flowdometer Connection Setup LWC.
 *
 * completeSetup  — enables Client Credentials on the packaged ECA and
 *                  sets the current admin as the Run-As user via a single
 *                  Metadata API SOAP updateMetadata call.
 *
 * checkConnectionStatus — acquires a client_credentials token through
 *                         FlowdometerTokenService and validates it against
 *                         the REST /limits endpoint.
 */
public with sharing class FlowdometerAuthService {

    private static final String API_VERSION = 'v62.0';
    private static final String SOAP_NS = 'http://soap.sforce.com/2006/04/metadata';

    public class ConnectionStatus {
        @AuraEnabled public Boolean connected   { get; set; }
        @AuraEnabled public Integer httpStatus   { get; set; }
        @AuraEnabled public String  message      { get; set; }
        @AuraEnabled public String  errorDetails { get; set; }
    }

    // ── Complete Setup ─────────────────────────────────────────────

    /**
     * One-click setup called by the LWC "Complete Setup" button.
     * Deploys an ECA policy update to enable Client Credentials and set
     * the current admin as Run-As user.
     *
     * Accepts an optional apiSessionId from the LWC (obtained from the
     * FlowdometerSession VF page) because Lightning sessions lack
     * Metadata API scope.  Falls back to UserInfo.getSessionId() if
     * not provided.
     */
    @AuraEnabled(cacheable=false)
    public static void completeSetup(String apiSessionId) {
        if (!hasCustomizeApplication()) {
            throw buildAuraException(
                'Only administrators with the Customize Application permission can configure Flowdometer.');
        }

        String baseUrl    = URL.getOrgDomainUrl().toExternalForm();
        String sessionId  = String.isNotBlank(apiSessionId) ? apiSessionId : getApiSession();
        String adminUser  = UserInfo.getUserName();
        String ecaRef     = resolveEcaReference();
        String policyName = resolvePolicyName();

        String soapEnvelope = buildUpdateMetadataEnvelope(
            sessionId, policyName, ecaRef, adminUser
        );

        HttpRequest req = new HttpRequest();
        req.setEndpoint(baseUrl + '/services/Soap/m/62.0');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'text/xml; charset=UTF-8');
        req.setHeader('SOAPAction', 'updateMetadata');
        req.setBody(soapEnvelope);
        req.setTimeout(30000);

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (CalloutException e) {
            throw buildAuraException('Could not reach the Metadata API. Please try again.');
        }

        if (res.getStatusCode() != 200 || !res.getBody().contains('<success>true</success>')) {
            String detail = parseSOAPError(res.getBody());
            throw buildAuraException(
                'Setup failed: ' + (String.isNotBlank(detail) ? detail : 'HTTP ' + res.getStatusCode()));
        }

        System.debug(LoggingLevel.INFO,
            'Flowdometer setup completed by user ' + UserInfo.getUserId() + ' at ' + System.now());
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

    // ── Helpers ────────────────────────────────────────────────────

    @TestVisible
    private static Boolean hasCustomizeApplication() {
        return [
            SELECT COUNT() FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
            AND PermissionSet.PermissionsCustomizeApplication = true
        ] > 0;
    }

    private static String resolveNamespace() {
        String className = FlowdometerAuthService.class.getName();
        return className.contains('.') ? className.substringBefore('.') : '';
    }

    private static String resolveEcaReference() {
        String ns = resolveNamespace();
        return String.isNotBlank(ns)
            ? ns + '__Flowdometer_ECA'
            : 'Flowdometer_ECA';
    }

    private static String resolvePolicyName() {
        return 'Flowdometer_ECA_oauth_defaultPolicy';
    }

    @TestVisible
    private static String buildUpdateMetadataEnvelope(
        String sessionId, String policyName, String ecaRef, String adminUser
    ) {
        return '<?xml version="1.0" encoding="UTF-8"?>'
            + '<soapenv:Envelope'
            + ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'
            + ' xmlns:met="' + SOAP_NS + '"'
            + ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
            + '<soapenv:Header>'
            + '<met:SessionHeader>'
            + '<met:sessionId>' + sessionId + '</met:sessionId>'
            + '</met:SessionHeader>'
            + '</soapenv:Header>'
            + '<soapenv:Body>'
            + '<met:updateMetadata>'
            + '<met:metadata xsi:type="met:ExtlClntAppOauthConfigurablePolicies">'
            + '<met:fullName>' + escapeXml(policyName) + '</met:fullName>'
            + '<met:isClientCredentialsFlowEnabled>true</met:isClientCredentialsFlowEnabled>'
            + '<met:clientCredentialsFlowUser>' + escapeXml(adminUser) + '</met:clientCredentialsFlowUser>'
            + '<met:externalClientApplication>' + escapeXml(ecaRef) + '</met:externalClientApplication>'
            + '</met:metadata>'
            + '</met:updateMetadata>'
            + '</soapenv:Body>'
            + '</soapenv:Envelope>';
    }

    private static String parseSOAPError(String responseBody) {
        if (String.isBlank(responseBody)) return null;
        // Extract content between <statusCode>…</statusCode> or <message>…</message>
        String msg = extractTag(responseBody, 'message');
        if (String.isBlank(msg)) {
            msg = extractTag(responseBody, 'statusCode');
        }
        return msg;
    }

    private static String extractTag(String xml, String tagName) {
        String open  = '<' + tagName + '>';
        String close = '</' + tagName + '>';
        Integer startIdx = xml.indexOf(open);
        Integer endIdx   = xml.indexOf(close);
        if (startIdx >= 0 && endIdx > startIdx) {
            return xml.substring(startIdx + open.length(), endIdx);
        }
        return null;
    }

    private static String getApiSession() {
        try {
            PageReference vfPage = Page.FlowdometerSession;
            Blob content = vfPage.getContent();
            String pageBody = content.toString().trim();
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(pageBody);
            String sid = (String) parsed.get('sid');
            if (String.isNotBlank(sid)) {
                return sid;
            }
        } catch (Exception e) {
            // Fall through to Lightning session
        }
        return UserInfo.getSessionId();
    }

    private static AuraHandledException buildAuraException(String msg) {
        AuraHandledException ex = new AuraHandledException(msg);
        ex.setMessage(msg);
        return ex;
    }

    private static String escapeXml(String input) {
        if (String.isBlank(input)) return '';
        return input.replace('&', '&amp;')
                    .replace('<', '&lt;')
                    .replace('>', '&gt;')
                    .replace('"', '&quot;')
                    .replace('\'', '&apos;');
    }
}
