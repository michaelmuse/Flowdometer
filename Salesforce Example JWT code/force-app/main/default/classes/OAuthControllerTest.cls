@isTest
public class OAuthControllerTest {

    private static string mockSessionId = 'MOCK_SESSION_ID';

    @IsTest
    static void getToken() {
        OAuthController oac = new OAuthController();
        
        Test.setMock(HttpCalloutMock.class, new JwtMock());
        Test.startTest();
        string token = oac.getToken();
        Test.stopTest();
        Assert.isNotNull(token);
        Assert.areEqual(mockSessionId, token);
    }   

    private class JwtMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'text/json');
            res.setBody('{"access_token":"'+mockSessionId+'","scope":"api","instance_url":"'+URL.getOrgDomainUrl().toExternalForm()+'","id":"https://test.salesforce.com/id/'+UserInfo.getOrganizationId()+'/'+UserInfo.getUserId()+'","token_type":"Bearer"}');
            res.setStatusCode(200);
            return res;
        }
    }
   
}