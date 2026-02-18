global class OAuthController {

    public String errorMessage {get; private set;} 
    public String requestMessage {get; private set;}

    // use consumer key from the connected app. This is not a per-org setting and is not a secret.
    private static string consumerKey = '3MVG9n_YourConsumerKeyHere_9nfGcKW';

    // These values are set in the constructor
    private static string authEndpoint;
    private static string tokenAudience;

    private Boolean runningInASandbox {
        get {
            if (runningInASandbox == null) {
                runningInASandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
            }
            return runningInASandbox;
        }
        set;
    }
    
    global OAuthController() { 
        errorMessage = 'User has not yet been authorized';
        requestMessage = 'Please authorize the user to use the JWTAuth connected app and then return to this page';

        if(runningInASandbox) {
            // Sandbox orgs, including Scratch orgs, need a different endpoint and audience
            authEndpoint = 'https://test.salesforce.com/services/oauth2/token';
            tokenAudience = 'https://test.salesforce.com';
        } else {
            // Production
            authEndpoint = 'https://login.salesforce.com/services/oauth2/token';
            tokenAudience = 'https://login.salesforce.com';
        }
    }
           
    global string getToken() {
        JWTRaw jwt = new JWTRaw('RS256');
        jwt.pkcs8 = cleanBase64Key(loadBase64Key());
        jwt.iss = consumerKey;
        jwt.sub = UserInfo.getUserName();
        jwt.aud = tokenAudience;
        
        //will return null if the user is not yet authorized
        String accessToken = getAccessToken(authEndpoint, jwt);
        return accessToken;
    }

    private string cleanBase64Key(string data) {
        //cut and paste of the private key adds line breaks, these must be removed
        string cleaned = data.replace('\n','').replace('\r','');
        return cleaned;
    }

    private string loadBase64Key() {
        // modify this if a different name is chosen for mdt containing private key
        string keyLabel = 'jwtAuthKey';
        List<jwtAuthKey__mdt> mdts = [SELECT value__c FROM jwtAuthKey__mdt WHERE MasterLabel= :keyLabel LIMIT 1];
        if(mdts.size() == 0) {
            // The jwtAuthKey Custom Metadata Record needs to be included in the package
            throw new JwtAuthException('Failed to get jwtAuthKey');
        }
        return mdts[0].value__c;
    }

    private static string getAccessToken(String tokenAuthEndpoint, JWTRaw jwt) {
    	// see https://github.com/salesforceidentity/jwt
        String access_token = null;
        String body = 'grant_type='+EncodingUtil.urlEncode('urn:ietf:params:oauth:grant-type:jwt-bearer', 'UTF-8')+'&assertion=' + jwt.issue();
        HttpRequest req = new HttpRequest();                            
        req.setMethod('POST');
        req.setEndpoint(tokenAuthEndpoint);
        req.setHeader('Content-type', 'application/x-www-form-urlencoded');
        req.setBody(body);

        Http http = new Http();               
        HTTPResponse res = http.send(req);
        
        if ( res.getStatusCode() == 200 ) {
            string responseBody = res.getBody();
            System.JSONParser parser = System.JSON.createParser(res.getBody());
            while (parser.nextToken() != null) {
                if ((parser.getCurrentToken() == JSONToken.FIELD_NAME) && (parser.getText() == 'access_token')) {
                    parser.nextToken();
                    access_token = parser.getText();
                    break;
                }
            }
        } else {
            system.debug(LoggingLevel.Error, 'endpoint: '+req.getEndPoint());
            system.debug(LoggingLevel.Error, 'statuscode: '+res.getStatusCode());
            system.debug(LoggingLevel.Error, 'status: '+res.getStatus());
            system.debug(LoggingLevel.Error, 'error: '+res.getBody());
            throw new JwtAuthException('OAuth Failure: ' + res.getStatusCode() + '/nBody:' + res.getBody());
        }
        return access_token;       
    }
    
    class JwtAuthException extends Exception {}   

}