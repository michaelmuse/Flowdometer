/**
 * @description HTTP callout mock for Tooling API requests used in tests
 * This allows tests to verify business logic without requiring real API authentication
 */
@IsTest
public class ToolingAPIMock implements HttpCalloutMock {
    private Integer statusCode;
    private String responseBody;
    private String expectedEndpoint;
    
    /**
     * @description Create a mock that returns a specific status code and response body
     * @param code The HTTP status code to return (e.g., 200, 401, 404, 500)
     * @param body The JSON response body to return
     */
    public ToolingAPIMock(Integer code, String body) {
        this.statusCode = code;
        this.responseBody = body;
        this.expectedEndpoint = null;
    }
    
    /**
     * @description Create a mock with endpoint validation
     * @param code The HTTP status code to return
     * @param body The JSON response body to return
     * @param endpoint The expected endpoint URL (for validation)
     */
    public ToolingAPIMock(Integer code, String body, String endpoint) {
        this.statusCode = code;
        this.responseBody = body;
        this.expectedEndpoint = endpoint;
    }
    
    /**
     * @description Respond to HTTP requests with the configured response
     */
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode);
        res.setHeader('Content-Type', 'application/json');
        
        // Validate endpoint if expected endpoint is set
        if (expectedEndpoint != null) {
            System.assert(
                req.getEndpoint().contains(expectedEndpoint),
                'Expected endpoint to contain: ' + expectedEndpoint + ', but got: ' + req.getEndpoint()
            );
        }
        
        // Return appropriate response based on status code
        if (statusCode == 200) {
            // Success responses
            if (String.isNotBlank(responseBody)) {
                res.setBody(responseBody);
            } else {
                // Default success response for Tooling API
                res.setBody('{"success":true}');
            }
        } else if (statusCode == 401) {
            // Unauthorized - authentication failed
            res.setBody('{"message":"Session expired or invalid","errorCode":"INVALID_SESSION_ID"}');
        } else if (statusCode == 404) {
            // Not found
            res.setBody('{"message":"The requested resource does not exist","errorCode":"NOT_FOUND"}');
        } else if (statusCode >= 500) {
            // Server error
            res.setBody('{"message":"An internal server error has occurred","errorCode":"SERVER_ERROR"}');
        } else {
            // Generic error
            res.setBody(String.isNotBlank(responseBody) ? responseBody : '{"success":false}');
        }
        
        return res;
    }
    
    /**
     * @description Multi-mock that handles different endpoints with different responses
     */
    public class MultiMock implements HttpCalloutMock {
        private Map<String, HttpResponse> endpointResponses = new Map<String, HttpResponse>();
        
        public void addResponse(String endpointPattern, Integer statusCode, String body) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            res.setHeader('Content-Type', 'application/json');
            endpointResponses.put(endpointPattern, res);
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            // Find matching response based on endpoint
            for (String pattern : endpointResponses.keySet()) {
                if (req.getEndpoint().contains(pattern)) {
                    return endpointResponses.get(pattern);
                }
            }
            
            // Default response if no match found
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"success":true}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
    
    /**
     * @description Create a mock for successful FieldDefinition queries
     */
    public static ToolingAPIMock createFieldDefinitionQuerySuccess() {
        String queryResponse = '{"size":1,"totalSize":1,"done":true,"queryLocator":null,"entityTypeName":"FieldDefinition","records":[{"Id":"00N000000000001","QualifiedApiName":"Account.Name","IsFieldHistoryTracked":false}]}';
        return new ToolingAPIMock(200, queryResponse);
    }
    
    /**
     * @description Create a mock for successful FieldDefinition updates
     */
    public static ToolingAPIMock createFieldDefinitionUpdateSuccess() {
        return new ToolingAPIMock(200, '{"success":true,"id":"00N000000000001"}');
    }
    
    /**
     * @description Create a mock for successful CustomField queries
     */
    public static ToolingAPIMock createCustomFieldQuerySuccess() {
        String queryResponse = '{"size":0,"totalSize":0,"done":true,"queryLocator":null,"entityTypeName":"CustomField","records":[]}';
        return new ToolingAPIMock(200, queryResponse);
    }
    
    /**
     * @description Create a mock for successful CustomField deletion
     */
    public static ToolingAPIMock createCustomFieldDeleteSuccess() {
        return new ToolingAPIMock(204, '');
    }
    
    /**
     * @description Create a mock for authentication failures
     */
    public static ToolingAPIMock createAuthenticationError() {
        return new ToolingAPIMock(401, '{"message":"Session expired or invalid","errorCode":"INVALID_SESSION_ID"}');
    }
    
    /**
     * @description Create a mock for NamedCredential queries
     */
    public static ToolingAPIMock createNamedCredentialQuerySuccess() {
        String queryResponse = '{"size":1,"totalSize":1,"done":true,"records":[{"Id":"0XA000000000001","DeveloperName":"Named_Cred","EndpointUrl":"https://login.salesforce.com"}]}';
        return new ToolingAPIMock(200, queryResponse);
    }
}
